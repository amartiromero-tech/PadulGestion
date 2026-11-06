# Security staging — verified

This branch remains connected only to mzbivhwuznrbvxurbuys (AMR Pruebas Seguridad). Do not merge its staging configuration into production. Production candidate and coordinated rollout are separate from this preview.

## Completed validation

- 24 automated access/appointment tests, 5 patient scenario groups, 5 service-worker groups and syntax checks passed.
- Real password login, logout and session restoration in a browser against staging passed with a fictitious account explicitly authorized by the user.
- One fictitious patient and two distinct appointments were saved and survived reload.
- Reception saw only authorized screens and no clinical notes/reasons. Updating an appointment price preserved its clinical reason in the database.
- Rebuilt lists now keep Delete restricted to administrators; patient deletion is disabled.
- Logout clears cached data, forms, signature and password. Pending reads and account changes cannot repopulate old data.
- The fictitious account's membership has been deactivated; its credentials are not in source control.
- SQL access suite passed against real staging RLS, including tenant isolation, inactive/unassigned accounts, role escalation, restricted reception RPCs and immutable audit.
- Staging migration amr_fail_closed_membership_roles ensures identical duplicate admin roles remain usable, while contradictory roles deny data at the database level. tests/membership-duplicates-staging.sql reproduces production's historical duplicates transactionally.
- The proposed production migration, access postflight and emergency restore were exercised in transactions on staging and rolled back. The restore reproduced the original production policies and table grants.
- Read-only production preflight passed. No production permissions, users, patients or appointments changed.

The local copy of the same staged source was used for browser acceptance because Vercel previews require Vercel authentication. Deployment protection was not disabled. The full browser test was against real staging Auth and RLS, not mocks.

## Rollout

See production/README.md for coordinated steps, snapshot-drift preflight, proposed migration, read-only postflight and emergency-only restore. Do not rerun the old root pilot SQL files: they reopen access. Production is still on its existing open pilot permissions until an authorized rollout.

The current audit covers patient mutations only. Billing persistence and clinical evolution save handling remain separate work. Leaked-password protection remains disabled: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.
