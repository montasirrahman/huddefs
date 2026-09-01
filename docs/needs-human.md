# Needs a human decision

Packages skipped during conversion because the fix is a judgement call, not a
mechanical one. Each entry says what the definition does, why the v2 spec cannot
express it as-is, and what the options are.

---

## `alsa-lib` 1.2.14 — needs a second source tarball

**Category in triage:** EASY (the triage does not detect multi-source packages —
see the note at the bottom).

`[install]` unpacks a second, separate upstream tarball that no field in the
definition declares:

```
tar: ../alsa-ucm-conf-1.2.14.tar.bz2: Cannot open: No such file or directory
tar: Error is not recoverable: exiting now
```

The build itself succeeds — the library compiles and installs into `$DESTDIR`
correctly. The failure is at the point where the definition reaches for
`alsa-ucm-conf`, the ALSA Use Case Manager configuration, which upstream ships
as its own release.

**Why this is not mechanical:** `huddef-v2-spec.md` defines exactly one
`Source:` with one `Source-SHA256:`. There is no way to declare a second
upstream tarball, so any fix changes either the format or the package.

**Options, in the order I would consider them:**

1. **Add multi-source support to v2.** `Source-1:`/`Source-1-SHA256:`, or make
   `Source:` a list. Cleanest if other packages need it — worth checking before
   deciding, because the answer changes the format for all 245.
2. **Split `alsa-ucm-conf` into its own package** and put it in
   `Build-Depends`. Matches how the repository already treats separable
   components, and needs no format change. It does mean a new package.
3. **Drop the ucm-conf step.** Smallest change, but it silently removes
   configuration that the shipped 1.2.14 package currently contains, so the
   rebuilt package would not match what is deployed.

I have not chosen between these. (1) is a format decision and (2) creates a
package, and both are yours.

**Note on the triage:** `alsa-lib` was classified EASY because the triage checks
for patches, `pip3`, network calls and absolute paths — not for a build section
reaching for a tarball that is not declared. Other EASY packages may hide the
same thing. Worth a scan for `tar -x` / `tar x` inside build sections against a
path the definition never fetched.
