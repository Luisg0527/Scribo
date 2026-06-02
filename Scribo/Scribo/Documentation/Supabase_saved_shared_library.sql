-- Saved shared notebooks: per-user bookmarks for notebooks opened via share token (/b/…).
-- Syncs "My library" shared cards across devices (replaces UserDefaults-only storage).
-- Run in Supabase SQL editor after auth.users exists.

create table if not exists public.user_saved_shared_notebooks (
  user_id uuid not null references auth.users (id) on delete cascade,
  share_token uuid not null,
  title text not null,
  subtopic_count integer not null default 0,
  note_count integer not null default 0,
  preview_snippet text,
  added_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, share_token)
);

create index if not exists user_saved_shared_notebooks_user_added_idx
  on public.user_saved_shared_notebooks (user_id, added_at desc);

alter table public.user_saved_shared_notebooks enable row level security;

create policy "user_saved_shared_select_own"
on public.user_saved_shared_notebooks for select
using (auth.uid() = user_id);

create policy "user_saved_shared_insert_own"
on public.user_saved_shared_notebooks for insert
with check (auth.uid() = user_id);

create policy "user_saved_shared_update_own"
on public.user_saved_shared_notebooks for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "user_saved_shared_delete_own"
on public.user_saved_shared_notebooks for delete
using (auth.uid() = user_id);

-- Keep updated_at fresh on change (optional but handy)
create or replace function public.set_user_saved_shared_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists user_saved_shared_notebooks_updated_at on public.user_saved_shared_notebooks;
create trigger user_saved_shared_notebooks_updated_at
 before update on public.user_saved_shared_notebooks
  for each row
  execute procedure public.set_user_saved_shared_updated_at();
