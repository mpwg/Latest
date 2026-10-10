# Installation security boundary

The beta's shell, arbitrary package/receipt XPC API, private bundle-cache API and
direct CommerceKit integration are removed from application source and targets.
No production source uses `@unchecked Sendable`.

The broker accepts one JSON AppStoreClaim, validates one positive numeric ID,
derives user/group from the authenticated connection and constructs its own
argument/environment allowlist. Both peers require an Apple certificate chain,
the exact fork signing identifier and configured team. No ad-hoc production
exception exists. The broker stages signed, digest-pinned tools through opened
descriptors into root-owned private storage, avoiding a validation/reopen race.

Independent review found two additional concerns:

1. Pinned mas used an unverified package hardlink in user-writable cache for its
   root installer fallback. A repository-owned patch now delegates to the pinned
   package verifier: copy to root-private storage, verify Apple package signing,
   reject scripts, validate bundle identity/install location/payload paths, reject
   external existing symlinks, and pass only the protected package to installer.
   The installer-reported app path and receipt symlinks are checked before receipt
   writes. Unverifiable packages fail closed and require App Store.
2. XPC disconnect did not own the root task. OwnedRequest now cancels preflight;
   after installer handoff it permits bounded completion rather than interrupting
   package installation. The UI disables cancellation at handoff and prevents
   quitting while updates run. Core tests cover both states.

These checks are source- and fixture-verified. They do not constitute a root
exploit reproduction or native positive installation proof. mas's ID-based
selection still cannot establish full freedom from app-instance changes during
an install; native race/symlink/receipt acceptance remains required. PackageKit
and Apple package signatures are part of the remaining external trust boundary.

The legacy `com.max-langer.Latest` daemon is not silently registered, disabled or
modified. The new own-fork service has a separate identity.
