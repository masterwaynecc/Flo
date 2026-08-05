-- Partner sharing + profile helpers for dawt

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table if not exists public.cycle_share_snapshots (
  user_id uuid primary key references auth.users (id) on delete cascade,
  period_start date,
  period_end date,
  fertile_window_start date,
  fertile_window_end date,
  ovulation_day date,
  next_period_start date,
  cycle_day int,
  phase text,
  updated_at timestamptz not null default now()
);

create table if not exists public.partner_invites (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  code text not null unique,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'revoked', 'expired')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now()
);

create table if not exists public.partner_links (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  partner_user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'revoked')),
  created_at timestamptz not null default now(),
  unique (owner_user_id, partner_user_id),
  check (owner_user_id <> partner_user_id)
);

create index if not exists partner_invites_owner_idx on public.partner_invites (owner_user_id);
create index if not exists partner_links_partner_idx on public.partner_links (partner_user_id);
create index if not exists partner_links_owner_idx on public.partner_links (owner_user_id);

alter table public.cycle_share_snapshots enable row level security;
alter table public.partner_invites enable row level security;
alter table public.partner_links enable row level security;

drop policy if exists "share_select_own" on public.cycle_share_snapshots;
create policy "share_select_own" on public.cycle_share_snapshots
  for select using (auth.uid() = user_id);

drop policy if exists "share_select_partner" on public.cycle_share_snapshots;
create policy "share_select_partner" on public.cycle_share_snapshots
  for select using (
    exists (
      select 1 from public.partner_links pl
      where pl.owner_user_id = cycle_share_snapshots.user_id
        and pl.partner_user_id = auth.uid()
        and pl.status = 'active'
    )
  );

drop policy if exists "share_upsert_own" on public.cycle_share_snapshots;
create policy "share_upsert_own" on public.cycle_share_snapshots
  for insert with check (auth.uid() = user_id);

drop policy if exists "share_update_own" on public.cycle_share_snapshots;
create policy "share_update_own" on public.cycle_share_snapshots
  for update using (auth.uid() = user_id);

drop policy if exists "invites_select_own" on public.partner_invites;
create policy "invites_select_own" on public.partner_invites
  for select using (auth.uid() = owner_user_id);

drop policy if exists "invites_insert_own" on public.partner_invites;
create policy "invites_insert_own" on public.partner_invites
  for insert with check (auth.uid() = owner_user_id);

drop policy if exists "invites_update_own" on public.partner_invites;
create policy "invites_update_own" on public.partner_invites
  for update using (auth.uid() = owner_user_id);

drop policy if exists "links_select_involved" on public.partner_links;
create policy "links_select_involved" on public.partner_links
  for select using (auth.uid() = owner_user_id or auth.uid() = partner_user_id);

drop policy if exists "links_update_owner" on public.partner_links;
create policy "links_update_owner" on public.partner_links
  for update using (auth.uid() = owner_user_id);

create or replace function public.create_partner_invite()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into public.partner_invites (owner_user_id, code)
  values (v_uid, v_code);
  return v_code;
end;
$$;

create or replace function public.accept_partner_invite(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_invite public.partner_invites%rowtype;
  v_link_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_invite
  from public.partner_invites
  where code = upper(trim(invite_code))
    and status = 'pending'
    and expires_at > now()
  for update;

  if not found then
    raise exception 'invalid or expired invite';
  end if;

  if v_invite.owner_user_id = v_uid then
    raise exception 'cannot accept own invite';
  end if;

  insert into public.partner_links (owner_user_id, partner_user_id)
  values (v_invite.owner_user_id, v_uid)
  on conflict (owner_user_id, partner_user_id)
  do update set status = 'active'
  returning id into v_link_id;

  update public.partner_invites
  set status = 'accepted'
  where id = v_invite.id;

  return v_link_id;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.create_partner_invite() from public, anon;
revoke all on function public.accept_partner_invite(text) from public, anon;
grant execute on function public.create_partner_invite() to authenticated;
grant execute on function public.accept_partner_invite(text) to authenticated;
