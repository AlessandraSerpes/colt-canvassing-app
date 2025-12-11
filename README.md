# Colt Canvassing App (Flutter + Supabase)

Internal canvassing companion app for Colt Home Services.

This project was migrated from an older FlutterFlow app into a clean Flutter
codebase, with Supabase as the backend. It is currently intended to be run
locally by developers (not yet shipped to the App Store / Play Store).

---

## 1. Overview

**Main features**

- Email + password sign-in / sign-up (Supabase Auth).
- CHS code gate on sign-up (only people with the internal code can create accounts).
- Current code is 'chs2025', it can be changed in sign_in_page.dart
- Town → Street → House navigation driven from the `houses` table in Supabase.
- Per-house detail screen:
  - "Mark Knocked"
  - "Mark Answered"
  - "Mark Signed Up"
- Each status update:
  - Updates snapshot fields on the `houses` table
  - Adds a row into `house_events` for history
- Simple event history list on the house detail page (who knocked / answered / signed up and when).

**Tech stack**

- Flutter (Dart)
- Supabase (Postgres + Auth + PostgREST)
- Flutter web was **experimentally** built, but this project is currently
  considered **local-only** (run on a dev machine).

---

## 2. Project structure

Relevant folders under `lib/`:

- `core/theme/chs_colors.dart` – Colt brand colors.
- `features/auth/sign_in_page.dart` – combined Sign In / Sign Up UI + Supabase auth calls.
- `features/canvassing/`
  - `towns_page.dart` – loads list of towns from Supabase.
  - `streets_page.dart` – streets within a town.
  - `houses_page.dart` – houses for a street.
  - `house_details_page.dart` – status buttons + event history.
- `features/stats/` – (placeholder for any future statistics views).
- `main.dart` – Supabase initialization + app theme + root `MaterialApp`.

---

## 3. Supabase setup (current state)

The app assumes an existing Supabase project with:

### Tables

- `houses`
  - `address` (text, primary key or unique)
  - `town` (text)
  - `street` (text)
  - `zip` (text)
  - status snapshot fields:
    - `knocked` (bool, default `false`)
    - `knocked_time` (timestamptz, nullable)
    - `knocked_user` (text, nullable)
    - `answered` (bool, default `false`)
    - `answered_time` (timestamptz, nullable)
    - `answered_user` (text, nullable)
    - `signed_up` (bool, default `false`)
    - `signed_up_time` (timestamptz, nullable)
    - `signed_up_user` (text, nullable)

- `house_events`
  - `id` (bigint, PK, identity)
  - `address` (text, foreign key to `houses.address` ideally)
  - `created_at` (timestamptz)
  - `user_id` (uuid, from Supabase auth)
  - `user_email` (text)
  - `event_type` (text) – `'knocked' | 'answered' | 'signed_up'`
  - `notes` (text, nullable)

### Auth

- Email/password auth enabled.
- RLS policies:
  - `houses`: update allowed for authenticated users (currently permissive).
  - `house_events`: insert/select allowed for authenticated users.

---

## 4. Running the app locally

### Prerequisites

- Flutter SDK installed.
- Dart SDK bundled with Flutter.
- A Supabase project configured as described above.
- The Supabase URL and anon key set in `main.dart`:
