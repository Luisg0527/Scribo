-- Checks whether an email is already registered (login vs sign-up routing).
-- Run this entire file in Supabase → SQL → New query (same project as the app URL in SupabaseConfig).

create or replace function public.email_exists(check_email text)
returns boolean
language plpgsql
security definer
set search_path = auth, public
as $$
begin
  return exists (
    select 1
    from auth.users
    where lower(email) = lower(trim(check_email))
  );
end;
$$;

alter function public.email_exists(text) owner to postgres;

grant execute on function public.email_exists(text) to anon, authenticated;
