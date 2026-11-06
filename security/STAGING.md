# Security staging — AMR Clínicas PRO

Status: staging only. Do not merge or point this preview at production.
Preview project: mzbivhwuznrbvxurbuys (AMR Pruebas Seguridad).
Production website and permissions are unchanged.

## Verified database authorization

tests/access-staging.sql creates fictitious clinics, profiles and patients, exercises the deployed staging policies and rolls back every row. Identity sequences may advance. It uses SET LOCAL ROLE and synthetic JWT claims; it is not a password login test and creates no persistent Auth users.

Passed: anonymous access denied on all 9 tables; admin read/create/update within own clinic; foreign-clinic reads and writes denied; foreign patient references denied; immutable clinic identifiers; admin self-deactivation denied; reception limited RPCs omit patient notes and appointment reasons; reception cannot promote itself; fisio clinical writes allowed and appointment deletes denied; supervisor writes denied; inactive/unassigned users denied; audit generated for patient mutations and read-only for application users.

## Frontend

Requires server-validated getUser(), active membership and recognized role. Removes local mode, self-signup, fallback clinic creation and default admin. Identical historical duplicate memberships are tolerated without deleting them; conflicting roles deny access. Queries scope to the authorized clinic and fail closed on errors. Reception reads/writes through existing minimal RPCs. Fisio does not request financial data. Supervisor save buttons are disabled. Patient deletion is disabled to preserve history; appointment deletion remains admin-only. Logout clears cached data, forms, lists and signature canvas, and ignores old in-flight reads. Role/clinic changes clear previous data.

## Validation

- node --test tests/access.cjs tests/citas.test.cjs — 23 passed
- node tests/patients.cjs — 5 scenario groups passed
- node tests/service-worker.cjs — 5 scenario groups passed
- node --check app.js — passed

Mock tests verify frontend routing and races. SQL tests verify real staging RLS. Full browser/password acceptance remains pending.

## Before production

1. Review roles against staff duties. Admin memberships are protected and managed outside the app in this baseline.
2. Export production permissions and prepare transactional migration and controlled rollback. Do not rerun old root supabase_*.sql pilot scripts: they reopen access.
3. Recheck duplicate admin mappings, null clinic IDs and cross-clinic references. No production data cleanup has been performed.
4. Provision a fictitious staging Auth account and verify browser login/logout/refresh plus patient and appointment saves. Do not share real passwords in chat.
5. Coordinate DB and frontend rollout; replace preview URL/key and remove staging banner in a separate production change.
6. Verify the confirmed production administrator can still work before marking rollout complete.

## Limits

Production remains under its existing open pilot permissions until rollout. This PR does not close production access. Existing audit covers patients only; broader audit, billing persistence and clinical evolution saves are separate work. Leaked password protection remains disabled: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.
