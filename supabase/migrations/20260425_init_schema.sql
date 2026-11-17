-- ============================================================================
-- GoldVault — initial schema
-- Run this in the Supabase SQL editor (or via `supabase db push`).
-- It creates tables, RLS policies, helper functions, and seeds sample data.
-- ============================================================================

-- ---------- Extensions ----------
create extension if not exists "pgcrypto";

-- ============================================================================
-- TABLES
-- ============================================================================

-- 1. profiles ----------------------------------------------------------------
create table if not exists public.profiles (
    id          uuid primary key references auth.users(id) on delete cascade,
    full_name   text,
    email       text,
    phone       text,
    is_admin    boolean not null default false,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

-- 2. wallets -----------------------------------------------------------------
create table if not exists public.wallets (
    user_id        uuid primary key references auth.users(id) on delete cascade,
    cash_balance   numeric(14,2) not null default 0 check (cash_balance >= 0),
    gold_grams     numeric(14,4) not null default 0 check (gold_grams >= 0),
    updated_at     timestamptz not null default now()
);

-- 3. gold_prices -------------------------------------------------------------
create table if not exists public.gold_prices (
    id              uuid primary key default gen_random_uuid(),
    price_per_gram  numeric(12,2) not null check (price_per_gram > 0),
    currency        text not null default 'INR',
    effective_at    timestamptz not null default now(),
    set_by          uuid references auth.users(id)
);

create index if not exists idx_gold_prices_effective_at
    on public.gold_prices (effective_at desc);

-- 4. transactions ------------------------------------------------------------
do $$
begin
    if not exists (select 1 from pg_type where typname = 'txn_type_enum') then
        create type txn_type_enum as enum
            ('top_up','buy_gold','sell_gold','redemption','adjustment');
    end if;
    if not exists (select 1 from pg_type where typname = 'txn_status_enum') then
        create type txn_status_enum as enum
            ('pending','completed','failed','cancelled');
    end if;
end$$;

create table if not exists public.transactions (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references auth.users(id) on delete cascade,
    txn_type        txn_type_enum not null,
    amount_inr      numeric(14,2) not null default 0,
    gold_grams      numeric(14,4) not null default 0,
    price_per_gram  numeric(12,2) not null default 0,
    status          txn_status_enum not null default 'completed',
    note            text,
    created_at      timestamptz not null default now()
);

create index if not exists idx_transactions_user_created
    on public.transactions (user_id, created_at desc);

-- 5. jewellery_catalog -------------------------------------------------------
create table if not exists public.jewellery_catalog (
    id                  uuid primary key default gen_random_uuid(),
    name                text not null,
    description         text,
    weight_grams        numeric(10,3) not null check (weight_grams > 0),
    making_charges_inr  numeric(12,2) not null default 0 check (making_charges_inr >= 0),
    image_url           text,
    in_stock            boolean not null default true,
    created_at          timestamptz not null default now()
);

-- 6. redemption_requests -----------------------------------------------------
do $$
begin
    if not exists (select 1 from pg_type where typname = 'redemption_status_enum') then
        create type redemption_status_enum as enum
            ('requested','approved','shipped','delivered','rejected','cancelled');
    end if;
end$$;

create table if not exists public.redemption_requests (
    id                  uuid primary key default gen_random_uuid(),
    user_id             uuid not null references auth.users(id) on delete cascade,
    item_id             uuid not null references public.jewellery_catalog(id),
    grams_redeemed      numeric(10,4) not null,
    making_charges_inr  numeric(12,2) not null default 0,
    shipping_address    text not null,
    status              redemption_status_enum not null default 'requested',
    admin_note          text,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

create index if not exists idx_redemption_user_created
    on public.redemption_requests (user_id, created_at desc);

-- ============================================================================
-- HELPER: is_admin()
-- ============================================================================
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select is_admin from public.profiles where id = auth.uid()),
    false
  );
$$;

-- ============================================================================
-- TRIGGER: auto-create profile + wallet on signup
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, email)
    values (new.id, new.email)
    on conflict (id) do nothing;

    insert into public.wallets (user_id)
    values (new.id)
    on conflict (user_id) do nothing;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ============================================================================
-- RPC FUNCTIONS (atomic balance changes)
-- ============================================================================

-- Top-up wallet (simulated payment) ----------------------------------------
create or replace function public.top_up_wallet(p_amount numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user uuid := auth.uid();
begin
    if v_user is null then
        raise exception 'Not authenticated';
    end if;
    if p_amount is null or p_amount <= 0 then
        raise exception 'Top-up amount must be positive';
    end if;

    update public.wallets
       set cash_balance = cash_balance + p_amount,
           updated_at   = now()
     where user_id = v_user;

    insert into public.transactions
        (user_id, txn_type, amount_inr, status, note)
    values
        (v_user, 'top_up', p_amount, 'completed', 'Wallet top-up');
end;
$$;

-- Buy gold from wallet cash --------------------------------------------------
create or replace function public.buy_gold(p_amount_inr numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user  uuid := auth.uid();
    v_price numeric;
    v_grams numeric;
    v_cash  numeric;
begin
    if v_user is null then
        raise exception 'Not authenticated';
    end if;
    if p_amount_inr is null or p_amount_inr <= 0 then
        raise exception 'Amount must be positive';
    end if;

    select price_per_gram into v_price
      from public.gold_prices
     order by effective_at desc
     limit 1;
    if v_price is null then
        raise exception 'No gold price set';
    end if;

    select cash_balance into v_cash
      from public.wallets where user_id = v_user for update;
    if v_cash is null or v_cash < p_amount_inr then
        raise exception 'Insufficient wallet balance';
    end if;

    v_grams := round(p_amount_inr / v_price, 4);

    update public.wallets
       set cash_balance = cash_balance - p_amount_inr,
           gold_grams   = gold_grams + v_grams,
           updated_at   = now()
     where user_id = v_user;

    insert into public.transactions
        (user_id, txn_type, amount_inr, gold_grams, price_per_gram,
         status, note)
    values
        (v_user, 'buy_gold', p_amount_inr, v_grams, v_price,
         'completed', 'Gold purchase');
end;
$$;

-- Sell gold back to wallet --------------------------------------------------
create or replace function public.sell_gold(p_grams numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user   uuid := auth.uid();
    v_price  numeric;
    v_amount numeric;
    v_have   numeric;
begin
    if v_user is null then
        raise exception 'Not authenticated';
    end if;
    if p_grams is null or p_grams <= 0 then
        raise exception 'Grams must be positive';
    end if;

    select price_per_gram into v_price
      from public.gold_prices
     order by effective_at desc
     limit 1;
    if v_price is null then
        raise exception 'No gold price set';
    end if;

    select gold_grams into v_have
      from public.wallets where user_id = v_user for update;
    if v_have is null or v_have < p_grams then
        raise exception 'Not enough gold to sell';
    end if;

    v_amount := round(p_grams * v_price, 2);

    update public.wallets
       set gold_grams   = gold_grams - p_grams,
           cash_balance = cash_balance + v_amount,
           updated_at   = now()
     where user_id = v_user;

    insert into public.transactions
        (user_id, txn_type, amount_inr, gold_grams, price_per_gram,
         status, note)
    values
        (v_user, 'sell_gold', v_amount, p_grams, v_price,
         'completed', 'Gold sold');
end;
$$;

-- Request a jewellery redemption ---------------------------------------------
create or replace function public.request_redemption(
    p_item_id uuid,
    p_shipping_address text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user      uuid := auth.uid();
    v_item      record;
    v_have      numeric;
    v_request   uuid;
begin
    if v_user is null then
        raise exception 'Not authenticated';
    end if;

    select * into v_item from public.jewellery_catalog
     where id = p_item_id and in_stock = true;
    if not found then
        raise exception 'Item not found or out of stock';
    end if;

    select gold_grams into v_have
      from public.wallets where user_id = v_user for update;
    if v_have is null or v_have < v_item.weight_grams then
        raise exception 'Not enough gold for this item';
    end if;

    -- Hold the gold (deduct immediately; refund if rejected later)
    update public.wallets
       set gold_grams = gold_grams - v_item.weight_grams,
           updated_at = now()
     where user_id = v_user;

    insert into public.redemption_requests
        (user_id, item_id, grams_redeemed,
         making_charges_inr, shipping_address)
    values
        (v_user, p_item_id, v_item.weight_grams,
         v_item.making_charges_inr, p_shipping_address)
    returning id into v_request;

    insert into public.transactions
        (user_id, txn_type, gold_grams, status, note)
    values
        (v_user, 'redemption', v_item.weight_grams,
         'pending', 'Redemption: ' || v_item.name);

    return v_request;
end;
$$;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
alter table public.profiles            enable row level security;
alter table public.wallets             enable row level security;
alter table public.transactions        enable row level security;
alter table public.gold_prices         enable row level security;
alter table public.jewellery_catalog   enable row level security;
alter table public.redemption_requests enable row level security;

-- profiles --------------------------------------------------------------
drop policy if exists "profiles self read"   on public.profiles;
drop policy if exists "profiles self update" on public.profiles;
drop policy if exists "profiles admin read"  on public.profiles;
drop policy if exists "profiles self upsert" on public.profiles;

create policy "profiles self read"
    on public.profiles for select
    using (id = auth.uid() or public.is_admin());

create policy "profiles self upsert"
    on public.profiles for insert
    with check (id = auth.uid());

create policy "profiles self update"
    on public.profiles for update
    using (id = auth.uid())
    with check (id = auth.uid());

-- wallets --------------------------------------------------------------
drop policy if exists "wallets self read"  on public.wallets;
drop policy if exists "wallets admin read" on public.wallets;

create policy "wallets self read"
    on public.wallets for select
    using (user_id = auth.uid() or public.is_admin());

-- transactions ---------------------------------------------------------
drop policy if exists "tx self read"  on public.transactions;
drop policy if exists "tx admin read" on public.transactions;

create policy "tx self read"
    on public.transactions for select
    using (user_id = auth.uid() or public.is_admin());

-- gold_prices: public read, admin write --------------------------------
drop policy if exists "gp anyone read"   on public.gold_prices;
drop policy if exists "gp admin insert"  on public.gold_prices;

create policy "gp anyone read"
    on public.gold_prices for select
    using (true);

create policy "gp admin insert"
    on public.gold_prices for insert
    with check (public.is_admin());

-- jewellery_catalog: public read, admin write --------------------------
drop policy if exists "jc anyone read"  on public.jewellery_catalog;
drop policy if exists "jc admin write"  on public.jewellery_catalog;

create policy "jc anyone read"
    on public.jewellery_catalog for select
    using (true);

create policy "jc admin write"
    on public.jewellery_catalog for all
    using (public.is_admin())
    with check (public.is_admin());

-- redemption_requests --------------------------------------------------
drop policy if exists "rr self read"   on public.redemption_requests;
drop policy if exists "rr self insert" on public.redemption_requests;
drop policy if exists "rr admin read"  on public.redemption_requests;
drop policy if exists "rr admin update" on public.redemption_requests;

create policy "rr self read"
    on public.redemption_requests for select
    using (user_id = auth.uid() or public.is_admin());

create policy "rr admin update"
    on public.redemption_requests for update
    using (public.is_admin())
    with check (public.is_admin());

-- ============================================================================
-- SEED DATA — opening gold price + sample jewellery
-- ============================================================================
insert into public.gold_prices (price_per_gram, currency)
values (7250.00, 'INR')
on conflict do nothing;

insert into public.jewellery_catalog
    (name, description, weight_grams, making_charges_inr, in_stock)
values
    ('Classic Gold Ring',  '22K gold ring, plain band',           4.000, 1500, true),
    ('Diamond Stud Earrings', '18K gold studs with VS diamond',   2.500, 4500, true),
    ('Gold Chain 16in',    '22K rope chain, 16 inches',           8.000, 2200, true),
    ('Bridal Necklace',    'Heritage design 22K choker',          18.500, 9500, true),
    ('Bangles (Pair)',     '22K plain bangles, pair',             14.000, 3800, true)
on conflict do nothing;
