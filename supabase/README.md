# Perch Supabase Backend

This directory contains reproducible Supabase SQL for the Perch backend foundation.

## Apply Order

1. Create the Supabase project and enable email/password auth in the dashboard.
2. Apply migrations/20260521190000_backend_foundation.sql.
3. Apply migrations/20260521192500_backend_foundation_hardening.sql.
4. Run tests/rls_foundation_checks.sql in a disposable Supabase project or local Supabase database to verify ownership policies.

Do not commit project URLs, anon keys, or service-role keys here. Keep real credentials in a local secrets store or untracked environment file.

## Current Caveat

The migrations were applied to Supabase project vuvtavravnenbemrgloy on 2026-05-21. The RLS verification script passed through the Supabase SQL executor, Supabase security advisors returned no warnings after the hardening migration, and performance advisors only reported expected unused-index INFO items for new indexes.
