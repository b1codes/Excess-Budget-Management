# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Excess Budget Management is a personal finance app for tracking income, managing accounts, budgeting expenses, and getting AI-powered fund allocation suggestions. Stack: Flutter (web) → Supabase (PostgreSQL + Auth + Edge Functions) → AWS (S3 + CloudFront via Terraform).

## Commands

### Frontend (Flutter)
```bash
cd frontend
flutter pub get           # Install dependencies
flutter run -d chrome     # Run locally on web
flutter build web         # Production build
flutter analyze           # Lint
flutter test              # Run all tests
flutter test test/path/to/test.dart  # Run a single test file
```

### Backend (Supabase)
```bash
cd backend
supabase start            # Start local dev (requires Docker)
supabase db reset         # Reset DB with migrations
supabase functions serve generate-suggestions  # Serve Edge Function locally
```

### Infrastructure (Terraform)
```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Architecture

### Layers
- **`frontend/`** — Flutter web app connecting to Supabase via `supabase_flutter` SDK
- **`backend/supabase/`** — PostgreSQL schema (migrations), Supabase Auth, and a Deno Edge Function
- **`infra/`** — Terraform deploying the Flutter build to AWS S3 + CloudFront

### Frontend Structure
Feature-first layout under `frontend/lib/features/`. Each feature (`auth`, `accounts`, `budget`, `dashboard`) follows:
```
[feature]/
├── bloc/           # BLoC events, states, and bloc class
├── models/         # Data models with fromJson/toJson
├── presentation/screens/
└── repositories/   # Supabase data access layer
```

Core wiring is in `frontend/lib/core/`:
- `router.dart` — GoRouter with auth-aware redirects
- `constants.dart` — Supabase project URL and anon key

### State Management
BLoC pattern (`flutter_bloc`). Each feature has its own bloc. UI widgets use `BlocBuilder`/`BlocListener` to react to state changes.

### Navigation
GoRouter (`go_router`). Routes redirect unauthenticated users to `/login`. Auth state comes from the `AuthBloc`.

### Supabase Schema
All tables use Row-Level Security (RLS) — users can only access their own rows. Key tables: `profiles`, `accounts`, `income_sources`, `extra_income`, `budget_categories`, `goals`. A trigger auto-creates a profile on signup.

### Edge Function
`backend/supabase/functions/generate-suggestions/index.ts` (Deno v2) — accepts user financial data, calls the Gemini API, and returns JSON allocation suggestions. Requires `GEMINI_API_KEY` env var.

### Infrastructure
Terraform deploys the Flutter web build to an S3 bucket (private, CloudFront-only access) behind a CloudFront distribution with SPA routing (404/403 → `/index.html`).

## Key Dependencies
- `supabase_flutter ^2.12.0` — Supabase client and auth
- `flutter_bloc ^9.1.1` — BLoC state management
- `go_router ^17.1.0` — Navigation
- `equatable ^2.0.8` — Value equality for BLoC states/events
- `google_fonts ^8.0.2` — Outfit font family

## Theme
Material 3, seed color `#2C5E4B` (dark teal/green). Font: Outfit via `google_fonts`.
