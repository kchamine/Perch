# Perch Supabase Backend

This directory contains reproducible Supabase SQL for the Perch backend foundation.

## Apply Order

1. Create the Supabase project and enable email/password auth in the dashboard.
2. Apply migrations/20260521190000_backend_foundation.sql.
3. Run tests/rls_foundation_checks.sql in a disposable Supabase project or local Supabase database to verify ownership policies.

Do not commit project URLs, anon keys, or service-role keys here. Keep real credentials in a local secrets store or untracked environment file.

## Current Caveat

The migration has been authored and statically checked in-repo. It has not been applied to a live Supabase project from this machine because the project credentials and CLI/runtime are not present.
