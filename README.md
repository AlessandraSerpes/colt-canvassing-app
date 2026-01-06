# Colt Canvassing App (Flutter + Supabase)

Internal canvassing companion app for Colt Home Services.

This project was migrated from an older FlutterFlow app into a clean Flutter
codebase, with Supabase as the backend. It is intended for internal use by
canvassers and managers and is currently deployed as a Flutter Web app.

---

## 1. Overview

### Main Features

- Email + password sign-in / sign-up using Supabase Auth
- CHS access code gate on sign-up  
  - Current code: `chs2025`
  - Defined in `sign_in_page.dart`
- Role-based access:
  - Canvasser
  - Manager
- Town → Street → House navigation driven from Supabase data
- Per-house detail screen actions:
  - Mark Knocked
  - Mark Answered
  - Mark Signed Up
- Each status update:
  - Updates snapshot fields on the `houses` table
  - Inserts a historical record into `house_events`
- Dashboards:
  - Canvasser dashboard (personal stats and paid time)
  - Manager dashboard (team stats and drilldowns)

### Tech Stack

- Flutter (Dart, web-first)
- Supabase (Postgres, Auth, RLS, RPCs, Views)
- Flutter Web deployed via GitHub Pages

---

## 2. Project Structure

Relevant folders under `lib/`:

- `core/`
  - `theme/chs_colors.dart` – Colt brand colors
  - `utils/address_format.dart` – ZIP code formatting and address helpers
- `features/auth/`
  - `sign_in_page.dart` – Sign in / sign up UI and CHS code gate
  - `role_gate_page.dart` – Determines canvasser vs manager routing
- `features/canvassing/`
  - `towns_page.dart` – Loads list of towns
  - `streets_page.dart` – Streets within a town
  - `houses_page.dart` – Houses for a street
  - `house_details_page.dart` – Status buttons and event history
- `features/stats/`
  - `canvasser/canvasser_dashboard_page.dart`
  - `manager/manager_dashboard_page.dart`
  - `manager/bucket_drilldown_page.dart`
- `main.dart`
  - Supabase initialization
  - App theme
  - Root `MaterialApp`

Navigation uses `Navigator.push` (no routing frameworks).

---

## 3. Supabase Setup (Current State)

The app assumes an existing Supabase project with the following schema.

### Tables

#### `houses`

- `address` (text, unique identifier)
- `town` (text)
- `street` (text)
- `zip` (text; stored as text to preserve leading zeros)
- Snapshot status fields:
  - `knocked` (bool)
  - `knocked_time` (timestamptz)
  - `knocked_user` (text)
  - `answered` (bool)
  - `answered_time` (timestamptz)
  - `answered_user` (text)
  - `signed_up` (bool)
  - `signed_up_time` (timestamptz)
  - `signed_up_user` (text)

#### `house_events`

- `id` (bigint, primary key)
- `address` (text)
- `created_at` (timestamptz)
- `user_id` (uuid, Supabase auth user)
- `user_email` (text)
- `event_type` (text: `knocked`, `answered`, `signed_up`)
- `notes` (text, nullable)

#### `profiles`

- `user_id` (uuid)
- `role` (text: `canvasser` or `manager`)

---

### Views (Used by Dashboards)

- `v_payroll_daily`
- `v_performance_daily`
- `v_manager_daily_summary`

Business logic for payroll and metrics lives in SQL views to keep Flutter UI simple.

---

### RPCs in Use

- `get_unique_towns`
  - Used by Towns page
  - Loads all towns once after login
- `get_houses_for_street`
  - Used by Houses page
  - Loads houses for selected street

---

### Security (RLS)

- Row Level Security enabled on all tables
- Access restricted to authenticated users
- Role-based behavior enforced in the UI via RoleGate

---

## 4. Authentication and Role Handling

### Sign-Up Flow

- User signs up with email and password
- Must enter valid CHS access code
- Supabase account is created
- Corresponding row must exist in `profiles`

### RoleGate

- RoleGate fetches `profiles.role`
- Routes user to:
  - `CanvasserDashboardPage` if role is `canvasser`
  - `ManagerDashboardPage` if role is `manager`

RoleGate is the single source of truth for role routing.

---

## 5. Dashboards and Metrics

### Canvasser Dashboard

Shows personal stats over a selected date range:

- Paid Time (hours)
- Doors Knocked
- People Answered
- Sign-ups
- Answer Rate
- Conversion Rate

#### Metric Definitions

- Answer Rate = `answers / knocks`
- Conversion Rate = `sign-ups / answers`
- Paid Time = `valid 15-minute buckets × 0.25`

Percentages are computed from summed totals, not averaged.

---

### Manager Dashboard

Shows team-wide daily summaries:

- Paid Time
- Valid 15-minute buckets
- Doors knocked
- Answer and conversion rates
- Knocks per paid hour

Clicking a row opens a bucket-level drilldown for auditing payroll logic.

---

## 6. Geotagging (Current Implementation)

Geotagging is implemented in a non-blocking, observational manner.

- Houses are pre-mapped to latitude and longitude using a Python script
- Coordinates stored on the `houses` table
- At time of knock:
  - User GPS location is captured
  - Distance to house location is calculated (Haversine)
- Distance difference is displayed and logged

Geotagging does not currently:
- Block actions
- Enforce hard distance limits
- Apply penalties

---

## 7. Running the App Locally

### Prerequisites

- Flutter SDK installed
- Supabase project configured
- Supabase URL and anon key available

### Configuration

Set Supabase credentials in `main.dart`:

```dart
await Supabase.initialize(
  url: 'https://<project>.supabase.co',
  anonKey: '<public-anon-key>',
);
