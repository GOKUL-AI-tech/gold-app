# GoldVault — Digital Gold Savings App

A Flutter mobile app + Supabase backend for saving money in real gold.
Inspired by digital gold savings apps like Thangamayil DigiGold.

## Features

**User**
- Email OTP login (Supabase Auth)
- Wallet (₹) with simulated top-up
- Buy / Sell gold at the live market price
- Gold holdings & current valuation
- Transaction history
- Redeem gold for jewellery (catalog + shipping address)
- Profile management

**Admin** (gated by `profiles.is_admin`)
- Update gold price (publishes a new price record)
- Manage users (view all, promote/demote admins)
- Approve / ship / reject redemption requests
- Reports: users, cash under custody, gold under custody, buy/sell volumes, pending redemptions

## Project structure

```
goldvault_app/
├── lib/
│   ├── main.dart                 # Supabase init + MaterialApp
│   ├── config/env.dart           # Supabase URL / anon key (override via --dart-define)
│   ├── theme/app_theme.dart      # GoldVault brand colors + Material 3 theme
│   ├── models/                   # Profile, Wallet, Txn, GoldPrice, JewelleryItem
│   ├── services/                 # AuthService, ProfileService, GoldService
│   ├── widgets/                  # Reusable money formatter + StatCard
│   └── screens/
│       ├── auth/                 # Login + OTP + AuthGate
│       ├── user/                 # Dashboard, wallet, buy, sell, history, redemption, profile
│       └── admin/                # Admin dashboard + price/users/redemptions/reports
├── supabase/
│   └── migrations/
│       └── 20260425_init_schema.sql   # Tables, RLS, RPC functions, seed data
├── pubspec.yaml
└── README.md
```

## Setup

### 1. Supabase

1. Open the Supabase project at `https://YOUR-PROJECT.supabase.co`.
2. Go to **SQL Editor → New query** and paste the contents of
   `supabase/migrations/20260425_init_schema.sql`. Run it.
   This creates all tables, RLS policies, helper RPCs, and seeds:
   - one opening gold price (₹7,250 / g)
   - five sample jewellery items
3. Go to **Authentication → Providers** and ensure **Email** is enabled (it is by default). The app uses 6-digit email OTPs (`signInWithOtp` + `verifyOTP`).
4. (Optional) In **Authentication → URL Configuration**, set your site URL.
5. To make yourself an admin after first sign-in, run in the SQL editor:
   ```sql
   update public.profiles
      set is_admin = true
    where email = 'your-email@example.com';
   ```

6. Stuck signing in? If your account was created via OTP only, password
   sign-in won't work until you set one. Either use **Set / Change
   Password** in the Profile tab after signing in via OTP, or run:
   ```sql
   update auth.users
      set email_confirmed_at = coalesce(email_confirmed_at, now()),
          encrypted_password  = crypt('your-new-password', gen_salt('bf'))
    where email = 'your-email@example.com';
   ```
   Note: in current Supabase, `confirmed_at` is a generated column —
   don't try to write to it.

### 2. Flutter

```bash
cd goldvault_app
flutter pub get
flutter run
```

For production builds, pass the Supabase keys via `--dart-define` instead of relying on the defaults baked into `lib/config/env.dart`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

> Note: The `sb_publishable_*` key is Supabase's new publishable (anon) key format and is safe to ship in mobile clients — RLS does the actual access control.

## Architecture notes

- All wallet/gold balance changes go through Postgres functions
  (`top_up_wallet`, `buy_gold`, `sell_gold`, `request_redemption`) defined as `SECURITY DEFINER`. This keeps balance updates atomic — no client can corrupt their own balance, and `auth.uid()` is the only thing that decides who's affected.
- A trigger on `auth.users` (`handle_new_user`) auto-creates a `profiles` row + a zeroed-out `wallets` row whenever someone signs up.
- `gold_prices` is append-only: every price change is a new row. The "current price" is just `order by effective_at desc limit 1`. This gives a free price history for the admin charts.
- RLS rules:
  - Users can only read their own profile / wallet / transactions / redemption requests.
  - Admins can read everything (via the `is_admin()` helper).
  - `gold_prices` and `jewellery_catalog` are world-readable; only admins can write.

## Roadmap (not implemented yet)

- Real payment gateway integration (Razorpay / Stripe) for wallet top-up
- Push notifications when redemption status changes
- KYC flow before high-value redemptions
- Dark mode
- Localization (currently INR / English only)

## License

For demo / educational use.
