# Production access rollout — prepared, not applied

Production project: gjwxsaczasfprwochzyw. Staging: mzbivhwuznrbvxurbuys.
No production business data, memberships or permissions have been changed.
This branch contains a production-configured frontend candidate; staging validation is on PR #6.

## Verified

- Real password login in a browser against staging, using an explicitly authorized fictitious account. Local copy of the same app was used because Vercel previews require Vercel login; preview protection was not disabled.
- Admin created one fictitious patient and two separate appointments; both persisted after reload.
- Reception login hides clinical, admin and audit sections. Appointment RPCs omit clinical reasons.
- Reception changed a fictitious appointment price from 35 to 36; its clinical reason remained unchanged in the database.
- Logout cleared the forms, patient/appointment lists, signature and password field. The fictitious account's clinic membership was then deactivated. No credentials are saved in source control.
- A browser regression in rebuilt delete buttons was fixed: only admin appointment lists render Delete, and patient deletion is disabled.
- 24 automated access/appointment tests, plus 5 patient and 5 service-worker scenario groups.
- prepare.sql was exercised transactionally against staging with the complete SQL access suite and postflight checks; all passed and rolled back.
- Emergency restore was exercised transactionally: it reproduced all 34 original production policies and original table grants, then the entire test was rolled back.
- Identical duplicate admin roles keep access; contradictory active roles deny data access at the database level. Production duplicate membership rows are preserved, not edited.
- Production read-only preflight passed: one confirmed active administrator, no contradictory roles or broken clinic/patient references, no explicit column ACLs, snapshot matches current policies/grants.

## Files

- preflight.sql: read-only snapshot-drift and data-consistency checks. Run again immediately before rollout.
- prepare.sql: transactional permission/function/constraint/trigger change. No business-row INSERT/UPDATE/DELETE. Replaces pilot policies with authenticated clinic/role policies, closes anonymous table/sequence access, limits reception RPCs and protects audit writes. Historical membership duplicates are left intact; no unique membership constraint is added.
- postflight.sql: read-only authorization checks using transaction-local claims for every confirmed active admin, without modifying patient records.
- snapshot-before.json: policies, ACLs, constraints and trigger metadata captured before the change. No patient records or private credentials.
- restore-pilot-permissions.sql: emergency-only restoration of the previously OPEN pilot permissions. Never run automatically. Reverting a frontend build while keeping restrictive policies is preferable.

## Ordered rollout

1. Confirm current production admin browser sign-in is available; retain Supabase dashboard/connector administrative access.
2. Run preflight.sql against the production project. Stop on any mismatch; regenerate the snapshot and review.
3. Apply prepare.sql atomically via a named Supabase migration. A statement/lock timeout or failed precondition must abort the whole transaction; do not retry individual grants or policies.
4. Run postflight.sql. It must show anonymous privileges closed and confirmed administrators retaining clinic and table access.
5. Merge/deploy this production frontend candidate and wait for Vercel's production success, including padul-gestion-csam. Never merge the staging-configured PR #6 into production.
6. Verify the served app/configuration, administrator access, appointments and patient forms. Use only read-only checks against real data; no fictitious production patient or appointment should be created.
7. Keep the reviewed snapshot and rollout commit SHA. Leave the emergency restore unused if checks pass.

The old frontend may show permission errors briefly between DB and frontend rollout. The change must be coordinated as a short deployment window. Removing only the visual login bypass would not secure the database.

## Limits and follow-up

No production rollout has occurred yet. Billing persistence/listing and clinical evolution error handling remain separate work. Existing audit covers patients only. Staging has only a leaked-password-protection warning, which remains to be handled separately: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.
