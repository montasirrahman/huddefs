# huddefs

Package definitions for **BlackFlag Linux**, a Linux From Scratch derivative.
One `.huddef` per package, under version control for the first time.

## Layout

```
huddefs/<package>/<package>.huddef        one canonical definition per package
huddefs/<package>/<package>.huddef.altN   rejected variants, kept for review
huddefs/<package>/patches/*.patch         patches, applied -Np1 in order
huddefs/<package>/files/*                 config files shipped with the package
attic/<package>/…                         never-published definitions, untouched
docs/                                     format spec, workflow, provenance
CLAUDE.md                                 rules for editing definitions — read first
```

## Where this came from

These definitions previously lived only on bf-repo, in
`/var/www/hud-repo/sources/definitions/`, as **941 files for 421 package names**
spread across directories named `old/`, `old/0`, `old/packages`,
`old/updated-packages`, `13 Feb 2026`, `14 Feb 2026/week1..4` and others. There
was no version control. `qemu-10.0.3.huddef` existed five times in three
genuinely different versions.

The consolidation rule: **the copy archived in `pool/main/<letter>/<name>/` is
canonical**, because `hud-repo-manager add` puts the `.huddef` next to the `.hud`
it produced — so that copy is the definition that actually built the shipped
package. Where copies disagreed, the pool copy won and the alternatives were kept
as `.altN` rather than discarded.

- **245 packages** consolidated — every package with a published `.hud`
- **96** needed a tiebreak, producing **134** `.alt` files
- **176 packages** went to [`attic/`](attic/) — definitions that were never
  published, so no tiebreaker exists for them

Full provenance for every file is in
[`docs/consolidation-manifest.md`](docs/consolidation-manifest.md); the analysis
behind it is in [`docs/duplicate-report.md`](docs/duplicate-report.md).

## Before editing anything

Read [`CLAUDE.md`](CLAUDE.md) and then
[`docs/huddef-v2-spec.md`](docs/huddef-v2-spec.md).

**These files are still v1.** They were copied verbatim so that git records what
actually shipped. None of them has `Source-SHA256:` or `Build-Depends:`, 72 of
them run `pip3 install` mid-build, and the conversion to v2 has not started.
That conversion is `docs/WORKFLOW.md` steps 3–4, and it is most of the remaining
work.

One known defect is already confirmed: `huddefs/qemu/qemu.huddef` guards both a
download and a patch with `|| true`, so the shipped qemu is almost certainly
unpatched. It is the only definition of the 245 that does this.

## The rules that matter most

1. **One definition per package.** The version lives inside the file. Never
   create `foo-1.2.3.huddef` next to `foo-1.2.4.huddef`, and never add a
   directory named `old/` or a dated one. Git holds the history — that is the
   whole point of this repository existing.
2. **No network access inside build sections**, and no `|| true` after a `patch`
   or a download.
3. **Never modify anything under `/var/www/hud-repo/`.** Publishing is a
   separate, human-approved step.
