-- MoneyFlow — initial schema
-- Wszystkie tabele uzytkownika mają RLS: kazdy user widzi tylko swoje dane.

-- =========================================================================
-- ENUMS
-- =========================================================================
create type category_type as enum ('income', 'expense');
create type account_type  as enum ('cash', 'checking', 'savings', 'credit_card', 'investment', 'loan');
create type billing_cycle as enum ('weekly', 'monthly', 'quarterly', 'yearly');
create type budget_period as enum ('weekly', 'monthly', 'yearly');

-- =========================================================================
-- PROFILES (rozszerzenie auth.users)
-- =========================================================================
create table public.profiles (
    id           uuid primary key references auth.users(id) on delete cascade,
    full_name    text,
    currency     text not null default 'PLN',
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

-- Trigger: po signupie auto-tworzymy profile
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, full_name)
    values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''));
    -- seed default categories for new user
    insert into public.categories (user_id, name, icon, color, type) values
        (new.id, 'Jedzenie',       'fork.knife',          '#FF9500', 'expense'),
        (new.id, 'Transport',      'car.fill',            '#007AFF', 'expense'),
        (new.id, 'Mieszkanie',     'house.fill',          '#5856D6', 'expense'),
        (new.id, 'Rozrywka',       'gamecontroller.fill', '#FF2D55', 'expense'),
        (new.id, 'Zakupy',         'bag.fill',            '#AF52DE', 'expense'),
        (new.id, 'Zdrowie',        'heart.fill',          '#FF3B30', 'expense'),
        (new.id, 'Subskrypcje',    'repeat',              '#34C759', 'expense'),
        (new.id, 'Inne',           'ellipsis.circle',     '#8E8E93', 'expense'),
        (new.id, 'Wynagrodzenie',  'banknote.fill',       '#34C759', 'income'),
        (new.id, 'Inne przychody', 'plus.circle.fill',    '#30D158', 'income');
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- =========================================================================
-- CATEGORIES
-- =========================================================================
create table public.categories (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    name        text not null,
    icon        text not null default 'circle.fill',  -- SF Symbol
    color       text not null default '#007AFF',      -- hex
    type        category_type not null default 'expense',
    created_at  timestamptz not null default now()
);
create index on public.categories(user_id);

-- =========================================================================
-- ACCOUNTS
-- =========================================================================
create table public.accounts (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    name        text not null,
    type        account_type not null default 'checking',
    balance     numeric(14,2) not null default 0,
    currency    text not null default 'PLN',
    icon        text not null default 'creditcard.fill',
    created_at  timestamptz not null default now()
);
create index on public.accounts(user_id);

-- =========================================================================
-- TRANSACTIONS
-- =========================================================================
create table public.transactions (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references auth.users(id) on delete cascade,
    account_id   uuid references public.accounts(id) on delete set null,
    category_id  uuid references public.categories(id) on delete set null,
    amount       numeric(14,2) not null,            -- ujemne = wydatek, dodatnie = przychod
    description  text not null default '',
    date         date not null default current_date,
    is_recurring boolean not null default false,
    created_at   timestamptz not null default now()
);
create index on public.transactions(user_id, date desc);

-- =========================================================================
-- SUBSCRIPTIONS
-- =========================================================================
create table public.subscriptions (
    id                  uuid primary key default gen_random_uuid(),
    user_id             uuid not null references auth.users(id) on delete cascade,
    name                text not null,
    amount              numeric(14,2) not null,
    billing_cycle       billing_cycle not null default 'monthly',
    next_billing_date   date not null,
    category_id         uuid references public.categories(id) on delete set null,
    icon                text not null default 'repeat',
    color               text not null default '#34C759',
    active              boolean not null default true,
    notes               text default '',
    created_at          timestamptz not null default now()
);
create index on public.subscriptions(user_id, next_billing_date);

-- =========================================================================
-- BILLS
-- =========================================================================
create table public.bills (
    id                    uuid primary key default gen_random_uuid(),
    user_id               uuid not null references auth.users(id) on delete cascade,
    name                  text not null,
    amount                numeric(14,2) not null,
    due_date              date not null,
    paid                  boolean not null default false,
    category_id           uuid references public.categories(id) on delete set null,
    reminder_days_before  int not null default 3,
    created_at            timestamptz not null default now()
);
create index on public.bills(user_id, due_date);

-- =========================================================================
-- BUDGETS
-- =========================================================================
create table public.budgets (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references auth.users(id) on delete cascade,
    category_id  uuid not null references public.categories(id) on delete cascade,
    amount       numeric(14,2) not null,
    period       budget_period not null default 'monthly',
    start_date   date not null default current_date,
    created_at   timestamptz not null default now(),
    unique (user_id, category_id, period)
);
create index on public.budgets(user_id);

-- =========================================================================
-- GOALS
-- =========================================================================
create table public.goals (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references auth.users(id) on delete cascade,
    name            text not null,
    target_amount   numeric(14,2) not null,
    current_amount  numeric(14,2) not null default 0,
    target_date     date,
    icon            text not null default 'target',
    color           text not null default '#007AFF',
    created_at      timestamptz not null default now()
);
create index on public.goals(user_id);

-- =========================================================================
-- NET WORTH SNAPSHOTS (do wykresu trendu)
-- =========================================================================
create table public.net_worth_snapshots (
    id                  uuid primary key default gen_random_uuid(),
    user_id             uuid not null references auth.users(id) on delete cascade,
    total_assets        numeric(14,2) not null default 0,
    total_liabilities   numeric(14,2) not null default 0,
    date                date not null default current_date,
    created_at          timestamptz not null default now(),
    unique (user_id, date)
);
create index on public.net_worth_snapshots(user_id, date desc);

-- =========================================================================
-- ROW LEVEL SECURITY
-- =========================================================================
alter table public.profiles            enable row level security;
alter table public.categories          enable row level security;
alter table public.accounts            enable row level security;
alter table public.transactions        enable row level security;
alter table public.subscriptions       enable row level security;
alter table public.bills               enable row level security;
alter table public.budgets             enable row level security;
alter table public.goals               enable row level security;
alter table public.net_worth_snapshots enable row level security;

-- profiles: user widzi/edytuje wlasny profil
create policy "profiles_self_select" on public.profiles for select using (auth.uid() = id);
create policy "profiles_self_update" on public.profiles for update using (auth.uid() = id);

-- generyczne policies "uzytkownik tylko swoje wiersze" dla pozostalych tabel
do $$
declare
    t text;
begin
    foreach t in array array[
        'categories', 'accounts', 'transactions', 'subscriptions',
        'bills', 'budgets', 'goals', 'net_worth_snapshots'
    ] loop
        execute format('create policy "%I_select" on public.%I for select using (auth.uid() = user_id)', t, t);
        execute format('create policy "%I_insert" on public.%I for insert with check (auth.uid() = user_id)', t, t);
        execute format('create policy "%I_update" on public.%I for update using (auth.uid() = user_id)', t, t);
        execute format('create policy "%I_delete" on public.%I for delete using (auth.uid() = user_id)', t, t);
    end loop;
end $$;

-- =========================================================================
-- REALTIME (publikacja dla supabase-realtime)
-- =========================================================================
alter publication supabase_realtime add table
    public.profiles,
    public.categories,
    public.accounts,
    public.transactions,
    public.subscriptions,
    public.bills,
    public.budgets,
    public.goals,
    public.net_worth_snapshots;
