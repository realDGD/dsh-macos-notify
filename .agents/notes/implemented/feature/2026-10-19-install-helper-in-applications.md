# Agent Note: Install the native helper in shared Applications

Status: implemented

## Problem

The helper was installed in the current user's Applications folder, while users expected to find it in the shared Applications folder. Changing only the destination would leave Desktop launching the old copy and prevent the installer from recognizing older uninstall records.

## Decision

The default helper destination is `/Applications/DSH Notify.app`. Desktop prefers that location and retains the user-directory lookup until migration. Installation retains settings and the bundle identity, backs up managed older copies and retires them only after the new build and signature verify. Backups are copied and checked before a same-directory retirement rename, so rollback does not depend on the home and application directories sharing a volume. Uninstallation locks and validates the location in its recognized ownership record, including the older user-directory record.

## Alternatives considered

**Keep the user-only destination.** It avoids shared-directory write requirements, but the user explicitly chose the shared Applications folder as the default.

**Change only the installer destination.** The Host's startup lookup and older ownership records would still point to the user directory, leaving installation and runtime behavior inconsistent.

## Consequences

Installation requires write access to the shared Applications folder and reports failure rather than elevating privileges or silently choosing another destination. Isolated directory overrides remain available for installer tests. Targeted installer and lifecycle regressions cover migration, rollback, draft protection, ownership checks, old-record removal and location preference; live notification behavior is a separate acceptance check.
