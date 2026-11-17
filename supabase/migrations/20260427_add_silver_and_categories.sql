-- ============================================================================
-- GoldVault — add silver support + jewellery categories
-- Idempotent; safe to run after the initial schema.
-- ============================================================================

-- 1. Silver prices table (mirror of gold_prices) ---------------------------
create table if not exists public.silver_prices (
    id              uuid primary key default gen_random_uuid(),
    price_per_gram  numeric(12,2) not null check (price_per_gram > 0),
    currency        text not null default 'INR',
    effective_at    timestamptz not null default now(),
    set_by          uuid references auth.users(id)
);

create index if not exists idx_silver_prices_effective_at
    on public.silver_prices (effective_at desc);

alter table public.silver_prices enable row level security;

drop policy if exists "sp anyone read"  on public.silver_prices;
drop policy if exists "sp admin insert" on public.silver_prices;

create policy "sp anyone read"
    on public.silver_prices for select
    using (true);

create policy "sp admin insert"
    on public.silver_prices for insert
    with check (public.is_admin());

-- 2. wallets.silver_grams ---------------------------------------------------
alter table public.wallets
    add column if not exists silver_grams numeric(14,4) not null default 0
    check (silver_grams >= 0);

-- 3. Extend txn_type enum with buy_silver / sell_silver ---------------------
do $$
begin
    if not exists (
        select 1 from pg_enum
         where enumlabel = 'buy_silver'
           and enumtypid = (select oid from pg_type where typname = 'txn_type_enum')
    ) then
        alter type txn_type_enum add value 'buy_silver';
    end if;
    if not exists (
        select 1 from pg_enum
         where enumlabel = 'sell_silver'
           and enumtypid = (select oid from pg_type where typname = 'txn_type_enum')
    ) then
        alter type txn_type_enum add value 'sell_silver';
    end if;
end$$;

-- 4. jewellery_catalog: metal + category columns ----------------------------
alter table public.jewellery_catalog
    add column if not exists metal    text not null default 'gold'
        check (metal in ('gold','silver')),
    add column if not exists category text not null default 'general';

-- Backfill categories on the existing seeded items
update public.jewellery_catalog set category = 'ring'      where name ilike '%ring%';
update public.jewellery_catalog set category = 'earrings'  where name ilike '%earring%';
update public.jewellery_catalog set category = 'chain'     where name ilike '%chain%';
update public.jewellery_catalog set category = 'necklace'  where name ilike '%necklace%';
update public.jewellery_catalog set category = 'bangle'    where name ilike '%bangle%';

-- 5. RPCs for silver buy / sell --------------------------------------------
create or replace function public.buy_silver(p_amount_inr numeric)
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
    if v_user is null then raise exception 'Not authenticated'; end if;
    if p_amount_inr is null or p_amount_inr <= 0 then
        raise exception 'Amount must be positive';
    end if;

    select price_per_gram into v_price
      from public.silver_prices
     order by effective_at desc limit 1;
    if v_price is null then raise exception 'No silver price set'; end if;

    select cash_balance into v_cash
      from public.wallets where user_id = v_user for update;
    if v_cash is null or v_cash < p_amount_inr then
        raise exception 'Insufficient wallet balance';
    end if;

    v_grams := round(p_amount_inr / v_price, 4);

    update public.wallets
       set cash_balance = cash_balance - p_amount_inr,
           silver_grams = silver_grams + v_grams,
           updated_at   = now()
     where user_id = v_user;

    insert into public.transactions
        (user_id, txn_type, amount_inr, gold_grams, price_per_gram,
         status, note)
    values
        (v_user, 'buy_silver', p_amount_inr, v_grams, v_price,
         'completed', 'Silver purchase');
end;
$$;

create or replace function public.sell_silver(p_grams numeric)
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
    if v_user is null then raise exception 'Not authenticated'; end if;
    if p_grams is null or p_grams <= 0 then
        raise exception 'Grams must be positive';
    end if;

    select price_per_gram into v_price
      from public.silver_prices
     order by effective_at desc limit 1;
    if v_price is null then raise exception 'No silver price set'; end if;

    select silver_grams into v_have
      from public.wallets where user_id = v_user for update;
    if v_have is null or v_have < p_grams then
        raise exception 'Not enough silver to sell';
    end if;

    v_amount := round(p_grams * v_price, 2);

    update public.wallets
       set silver_grams = silver_grams - p_grams,
           cash_balance = cash_balance + v_amount,
           updated_at   = now()
     where user_id = v_user;

    insert into public.transactions
        (user_id, txn_type, amount_inr, gold_grams, price_per_gram,
         status, note)
    values
        (v_user, 'sell_silver', v_amount, p_grams, v_price,
         'completed', 'Silver sold');
end;
$$;

-- 6. Seed initial silver price + extended catalog --------------------------
insert into public.silver_prices (price_per_gram, currency)
select 92.00, 'INR'
where not exists (select 1 from public.silver_prices);

insert into public.jewellery_catalog
    (name, description, weight_grams, making_charges_inr, in_stock, metal, category)
values
    -- Gold extras
    ('Solitaire Engagement Ring', '18K gold, 0.5 ct VVS diamond', 5.500, 8000, true, 'gold', 'ring'),
    ('Temple Necklace Set',       'Heritage 22K with matching earrings', 28.000, 14000, true, 'gold', 'set'),
    ('Filigree Bracelet',         '22K hand-crafted bracelet', 6.500, 2400, true, 'gold', 'bracelet'),
    ('Children''s Bangles',       '22K small bangles, set of 4', 6.000, 1500, true, 'gold', 'bangle'),
    ('Kasu Mala',                 'Traditional 22K coin necklace', 24.000, 10500, true, 'gold', 'necklace'),
    ('Half-hoop Earrings',        '22K classic hoops', 3.200, 1800, true, 'gold', 'earrings'),
    -- Silver
    ('Silver Anklet (Pair)',      '925 silver payal, pair', 25.000, 800, true, 'silver', 'anklet'),
    ('Silver Toe Rings (Pair)',   '925 silver, plain', 4.500, 300, true, 'silver', 'ring'),
    ('Silver Chain 18in',         '925 box chain, unisex', 12.000, 500, true, 'silver', 'chain'),
    ('Silver Pooja Lamp',         'Hand-engraved diya', 80.000, 1500, true, 'silver', 'pooja'),
    ('Silver Baby Spoon Set',     'Set of 2, 925 hallmarked', 35.000, 1200, true, 'silver', 'gift'),
    ('Silver Coin 10g',           '999 fine silver coin', 10.000, 200, true, 'silver', 'coin'),
    ('Silver Bracelet',           'Adjustable rope bracelet', 8.500, 600, true, 'silver', 'bracelet')
on conflict do nothing;
