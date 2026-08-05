alter table public.cycle_share_snapshots
  add column if not exists cycle_length int not null default 28;
