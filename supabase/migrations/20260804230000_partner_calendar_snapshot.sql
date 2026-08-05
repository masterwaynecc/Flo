-- Extra fields so partners can render a Flo-like calendar legend
-- without receiving the full symptom diary.
alter table public.cycle_share_snapshots
  add column if not exists period_length int not null default 5,
  add column if not exists display_handle text,
  add column if not exists logged_period_dates date[] not null default '{}';
