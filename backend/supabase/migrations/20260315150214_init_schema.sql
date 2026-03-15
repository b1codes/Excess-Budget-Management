-- Enable necessary extensions
create extension if not exists "uuid-ossp";

-- Profiles table (extends auth.users)
create table public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Turn on RLS for profiles
alter table public.profiles enable row level security;

-- Profiles RLS policies
create policy "Users can view own profile"
  on public.profiles for select
  using ( auth.uid() = id );

create policy "Users can update own profile"
  on public.profiles for update
  using ( auth.uid() = id );

-- Trigger to automatically create a profile for new users
create or function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Accounts table
create table public.accounts (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  balance numeric(12, 2) default 0.00 not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.accounts enable row level security;
create policy "Users can view own accounts" on public.accounts for select using ( auth.uid() = user_id );
create policy "Users can insert own accounts" on public.accounts for insert with check ( auth.uid() = user_id );
create policy "Users can update own accounts" on public.accounts for update using ( auth.uid() = user_id );
create policy "Users can delete own accounts" on public.accounts for delete using ( auth.uid() = user_id );

-- Income Sources table (regular income)
create table public.income_sources (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  expected_amount numeric(12, 2) not null,
  frequency text not null, -- e.g., 'weekly', 'bi-weekly', 'monthly'
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.income_sources enable row level security;
create policy "Users can view own income sources" on public.income_sources for select using ( auth.uid() = user_id );
create policy "Users can insert own income sources" on public.income_sources for insert with check ( auth.uid() = user_id );
create policy "Users can update own income sources" on public.income_sources for update using ( auth.uid() = user_id );
create policy "Users can delete own income sources" on public.income_sources for delete using ( auth.uid() = user_id );

-- Extra Income table (one-off)
create table public.extra_income (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  amount numeric(12, 2) not null,
  description text,
  date_received date not null default current_date,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.extra_income enable row level security;
create policy "Users can view own extra income" on public.extra_income for select using ( auth.uid() = user_id );
create policy "Users can insert own extra income" on public.extra_income for insert with check ( auth.uid() = user_id );
create policy "Users can update own extra income" on public.extra_income for update using ( auth.uid() = user_id );
create policy "Users can delete own extra income" on public.extra_income for delete using ( auth.uid() = user_id );

-- Budget Categories table
create table public.budget_categories (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  limit_amount numeric(12, 2) not null,
  spent_amount numeric(12, 2) default 0.00 not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.budget_categories enable row level security;
create policy "Users can view own budget categories" on public.budget_categories for select using ( auth.uid() = user_id );
create policy "Users can insert own budget categories" on public.budget_categories for insert with check ( auth.uid() = user_id );
create policy "Users can update own budget categories" on public.budget_categories for update using ( auth.uid() = user_id );
create policy "Users can delete own budget categories" on public.budget_categories for delete using ( auth.uid() = user_id );

-- Goals table
create table public.goals (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  target_amount numeric(12, 2) not null,
  current_amount numeric(12, 2) default 0.00 not null,
  target_date date,
  type text not null, -- 'short_term', 'long_term'
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.goals enable row level security;
create policy "Users can view own goals" on public.goals for select using ( auth.uid() = user_id );
create policy "Users can insert own goals" on public.goals for insert with check ( auth.uid() = user_id );
create policy "Users can update own goals" on public.goals for update using ( auth.uid() = user_id );
create policy "Users can delete own goals" on public.goals for delete using ( auth.uid() = user_id );
