-- User profiles (extends Supabase auth.users)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  display_name text,
  avatar text,
  color_value int,
  created_at timestamptz default now()
);

-- Daily history
create table if not exists public.daily_history (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  date date not null,
  reps int default 0,
  sessions int default 0,
  minutes int default 0,
  updated_at timestamptz default now(),
  unique(user_id, date)
);

-- Exercise stats
create table if not exists public.exercise_stats (
  user_id uuid references auth.users on delete cascade,
  exercise_name text,
  total_reps int default 0,
  updated_at timestamptz default now(),
  primary key (user_id, exercise_name)
);

-- Streaks
create table if not exists public.streaks (
  user_id uuid references auth.users on delete cascade primary key,
  current_streak int default 0,
  best_streak int default 0,
  last_workout_date date,
  updated_at timestamptz default now()
);

-- RLS
alter table public.profiles enable row level security;
alter table public.daily_history enable row level security;
alter table public.exercise_stats enable row level security;
alter table public.streaks enable row level security;

create policy if not exists "Users own their profiles" on public.profiles for all using (auth.uid() = id);
create policy if not exists "Users own their history" on public.daily_history for all using (auth.uid() = user_id);
create policy if not exists "Users own their exercise stats" on public.exercise_stats for all using (auth.uid() = user_id);
create policy if not exists "Users own their streaks" on public.streaks for all using (auth.uid() = user_id);
