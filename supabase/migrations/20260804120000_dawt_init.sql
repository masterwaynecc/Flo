-- dawt initial schema (Phase 0)
-- Cloud = source of truth; RLS locked to auth.uid()

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_handle text,
  locale text default 'en',
  age_gate_ok boolean not null default false,
  teen_mode boolean not null default false,
  life_stage_mode text not null default 'track',
  ai_context_consent boolean not null default false,
  typical_cycle_length int not null default 28,
  typical_period_length int not null default 5,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.day_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_date date not null,
  flow text not null default 'none',
  payload jsonb not null default '{}'::jsonb,
  client_id uuid not null,
  updated_at timestamptz not null default now(),
  unique (user_id, log_date)
);

create table if not exists public.predictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  as_of date not null,
  algorithm_version text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.ai_threads (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists day_logs_user_date_idx on public.day_logs (user_id, log_date desc);
create index if not exists ai_messages_thread_idx on public.ai_messages (thread_id, created_at);

alter table public.profiles enable row level security;
alter table public.day_logs enable row level security;
alter table public.predictions enable row level security;
alter table public.ai_threads enable row level security;
alter table public.ai_messages enable row level security;

create policy "profiles_select_own" on public.profiles for select using (auth.uid() = user_id);
create policy "profiles_upsert_own" on public.profiles for insert with check (auth.uid() = user_id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = user_id);
create policy "profiles_delete_own" on public.profiles for delete using (auth.uid() = user_id);

create policy "day_logs_select_own" on public.day_logs for select using (auth.uid() = user_id);
create policy "day_logs_insert_own" on public.day_logs for insert with check (auth.uid() = user_id);
create policy "day_logs_update_own" on public.day_logs for update using (auth.uid() = user_id);
create policy "day_logs_delete_own" on public.day_logs for delete using (auth.uid() = user_id);

create policy "predictions_select_own" on public.predictions for select using (auth.uid() = user_id);
create policy "predictions_insert_own" on public.predictions for insert with check (auth.uid() = user_id);
create policy "predictions_delete_own" on public.predictions for delete using (auth.uid() = user_id);

create policy "ai_threads_own" on public.ai_threads for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "ai_messages_own" on public.ai_messages for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
