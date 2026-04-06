-- Notebook (topic) share links: one token exposes the full topic tree for read-only viewing (Drive-style).
-- Run in Supabase SQL editor after `topics`, `subtopics`, `notes` exist.

-- 1) Table
create table if not exists public.topic_share_links (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.topics (id) on delete cascade,
  token uuid not null unique default gen_random_uuid(),
  created_by uuid not null references auth.users (id) on delete cascade,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists topic_share_links_topic_id_idx on public.topic_share_links (topic_id);
create index if not exists topic_share_links_token_idx on public.topic_share_links (token);

alter table public.topic_share_links enable row level security;

-- Owner can manage links for notebooks they own
create policy "topic_share_links_insert_own_topic"
on public.topic_share_links for insert
with check (
  auth.uid() = created_by
  and exists (
    select 1 from public.topics t
    where t.id = topic_share_links.topic_id
      and t.user_id = auth.uid()
  )
);

create policy "topic_share_links_select_own"
on public.topic_share_links for select
using (created_by = auth.uid());

create policy "topic_share_links_update_own"
on public.topic_share_links for update
using (created_by = auth.uid());

-- 2) Public read via security definer RPC (same pattern as single-note share)
create or replace function public.get_notebook_by_share_token(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic_id uuid;
  v_result jsonb;
begin
  select tsl.topic_id into v_topic_id
  from public.topic_share_links tsl
  where tsl.token = p_token
    and tsl.revoked_at is null
  limit 1;

  if v_topic_id is null then
    return null;
  end if;

  if not exists (select 1 from public.topics t where t.id = v_topic_id) then
    return null;
  end if;

  select jsonb_build_object(
    'topic',
    (
      select jsonb_build_object(
        'id', t.id,
        'user_id', t.user_id,
        'title', t.title,
        'created_at', t.created_at,
        'updated_at', t.updated_at
      )
      from public.topics t
      where t.id = v_topic_id
    ),
    'subtopics',
    coalesce(
      (
        select jsonb_agg(st_obj order by sort_created)
        from (
          select
            jsonb_build_object(
              'id', s.id,
              'topic_id', s.topic_id,
              'title', s.title,
              'created_at', s.created_at,
              'updated_at', s.updated_at,
              'notes', coalesce(notes_json.notes_arr, '[]'::jsonb)
            ) as st_obj,
            s.created_at as sort_created
          from public.subtopics s
          left join lateral (
            select jsonb_agg(
              jsonb_build_object(
                'id', n.id,
                'subtopic_id', n.subtopic_id,
                'workspace_id', n.workspace_id,
                'user_id', n.user_id,
                'title', n.title,
                'content', n.content,
                'created_at', n.created_at,
                'updated_at', n.updated_at
              )
              order by n.updated_at desc
            ) as notes_arr
            from public.notes n
            where n.subtopic_id = s.id
          ) notes_json on true
          where s.topic_id = v_topic_id
        ) subq
      ),
      '[]'::jsonb
    )
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_notebook_by_share_token(uuid) from public;
grant execute on function public.get_notebook_by_share_token(uuid) to anon, authenticated;
