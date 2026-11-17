-- ============================================================================
-- Extend `profiles` with the rich detail set used by the Profile screen
-- (matches the Thangamayil DigiGold profile layout).
-- Idempotent — safe to run repeatedly.
-- ============================================================================

alter table public.profiles
    -- Basic / verified flags
    add column if not exists email_verified  boolean not null default false,
    add column if not exists phone_verified  boolean not null default false,

    -- Personal
    add column if not exists gender          text,        -- Male / Female / Other / Prefer not to say
    add column if not exists date_of_birth   date,
    add column if not exists religion        text,
    add column if not exists marital_status  text,        -- Single / Married / Divorced / Widowed
    add column if not exists dependants      integer,

    -- Family
    add column if not exists wedding_date    date,
    add column if not exists spouse_name     text,
    add column if not exists spouse_gender   text,
    add column if not exists spouse_dob      date,

    -- Address (single primary address; expand to a child table later if needed)
    add column if not exists addr_label      text default 'Home', -- Home / Work / Other
    add column if not exists addr_door_no    text,
    add column if not exists addr_street     text,
    add column if not exists addr_area       text,
    add column if not exists addr_city       text,
    add column if not exists addr_state      text,
    add column if not exists addr_pincode    text,

    -- Identity proofs (only store last-4 / masked, never the full number)
    add column if not exists aadhaar_last4   text,
    add column if not exists pan_last4       text,

    -- Misc
    add column if not exists nearest_showroom text,
    add column if not exists avatar_url       text;

-- Update RLS — already covered by existing policies which key off id = auth.uid().

-- Convenience: backfill phone_verified=true for users that already have a phone
-- (since the OTP flow that captured the phone implies it was verified at signup).
update public.profiles
   set phone_verified = true
 where phone is not null and phone <> '' and phone_verified = false;

-- Same for email — Supabase already tracks email confirmation in auth.users,
-- so mirror it onto the profile so the UI doesn't need a separate join.
update public.profiles p
   set email_verified = true
  from auth.users u
 where p.id = u.id
   and u.email_confirmed_at is not null
   and p.email_verified = false;
