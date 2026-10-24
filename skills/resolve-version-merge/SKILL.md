---
name: resolve-version-merge
description: Resolve a merge conflict caused by two branches claiming the same package version number. Triggers - "merge conflict", "version conflict", "same version number", "CHANGELOG conflict", "bump version to resolve merge". Works for schema packages (libs/schema), python+typescript client packages, and any package versioned via pyproject.toml or package.json. Bumps our version above theirs, keeps both CHANGELOG entry sets, bumps the (often silently auto-merged) version source files, regenerates derived/generated artifacts, and pushes.
allowed-tools: Read, Edit, Bash, Grep
---

## Current State
- Branch: !`git branch --show-current 2>/dev/null || true`
- Unmerged files: !`git diff --name-only --diff-filter=U 2>/dev/null || true`
- Status: !`git status --short 2>/dev/null | head -20 || true`
- Version files present: !`find . -maxdepth 4 \( -name pyproject.toml -o -name package.json -o -name defaults -o -name __init__.py \) -not -path '*/node_modules/*' 2>/dev/null | head -20 || true`

## When this fires

Two branches each bumped the same package to the same version number with
different content, so the CHANGELOG (and sometimes README/generated files)
conflict, while the version *source* files auto-merge silently (both equal) and
end up WRONG. The fix: keep the other branch's number, bump ours above it, keep
both changelog entry sets, fix the auto-merged version files, regenerate derived
artifacts.

## Step 0 - Discover (do not assume paths)

1. **List conflicts** generically: `git diff --name-only --diff-filter=U`. Group
   them by package (e.g. `libs/schema/`, `client/python/`, `client/typescript/`).
2. **Locate each package's version SOURCE.** Look in this order - the first that
   exists wins:
   - `package.json` -> `"version"` field (TS/JS).
   - `pyproject.toml` -> static `version = "..."`.
   - `pyproject.toml` dynamic: `[tool.hatch.version] path = "..."` -> the real
     version lives in that file (e.g. `src/<pkg>/__init__.py` `__version__`),
     NOT pyproject.
   - A `Makefile`/`defaults`-style file with `VERSION=...` that a generator reads.
3. **Classify each conflicted file** as:
   - **SOURCE** - hand-authored: `CHANGELOG.md`, version files above.
   - **DERIVED** - generated/assembled, must NOT be hand-edited as the canonical
     fix: generated clients, `openapi.json`, `schema.json`, a `README.md`
     assembled via `cat CHANGELOG.md >> README.md`, a `config.ts` carrying
     `VERSION` + a build timestamp.

## Step 1 - Core algorithm (same-version collision)

- The OTHER branch's version stays as-is.
- OUR entry bumps to **their version + 1 minor** (middle number): `2.26.0 ->
  2.27.0`, `1.154.0 -> 1.155.0`, `3.12.0 -> 3.13.0`.
- In each conflicted `CHANGELOG.md`: keep BOTH entry sets. Place OUR entries under
  the new bumped header, ABOVE theirs. If both sides also added entries under a
  shared older header (e.g. both touched `# 3.11.0`), merge those bullet lists.
- Multi-language client pairs (python + typescript) carry INDEPENDENT version
  numbers - bump each on its own track. Keep prose cross-references coherent
  (e.g. a TS changelog line "matching the python client 2.27.0" must reflect the
  python bump you just made).

## Step 2 - Fix the silently auto-merged version files (critical)

Because both branches sat at the same number, git auto-merges the version SOURCE
files with NO conflict - they will NOT appear in `--diff-filter=U`, but they are
WRONG (still the colliding version). After resolving the CHANGELOG, manually bump
every version source you found in Step 0:
- python dynamic-hatch file (`__init__.py` `__version__`)
- `package.json` `"version"`
- `defaults` `VERSION=`
- `config.ts` `VERSION = "..."` (also regenerated below; set it anyway)

Skipping this ships two different feature sets under one already-used number.

## Step 3 - DERIVED files: regenerate, don't hand-edit

Find the repo's generator (a `Makefile` target, codegen script, or `make` rule).
Resolve the SOURCE first (CHANGELOG + version), then regenerate so derived files
fall out correctly.

- **Schema example:** regenerating produces `libs/schema/schema.json`.
- **verification-input example:** `make typescript-client` (depends on
  `generate-openapi-schema`) rewrites `client/typescript/config.ts` (VERSION +
  fresh timestamp) and the TS client, then appends CHANGELOG onto README via
  `cat CHANGELOG.md >> README.md`.

**README append gotcha:** if README is built by appending CHANGELOG, regenerating
on top of an already-appended README duplicates the changelog tail. Restore README
to its committed pre-append base (`git checkout <ref> -- <README>` or let the
generator overwrite it) BEFORE regenerating.

**Timestamp-only conflicts** (e.g. `config.ts` build timestamp) are cosmetic - do
not agonize over them; regeneration overwrites the line, or keep either side.

**Fallback when no generator is runnable** (missing docker / deps / tooling):
hand-resolve the derived file to its known-correct shape (take the merged content
with the bumped VERSION; for an appended README mirror the resolved CHANGELOG) and
note in the commit message that regeneration was done manually.

## Step 4 - Stage, commit, push

1. `git add -A` - stage EVERYTHING (avoids pre-commit stash conflicts).
2. Commit: `merge: resolve conflict by bumping <package> to <NEW_VERSION>`
   (list both numbers for a client pair, e.g. `py 2.27.0 / ts 3.13.0`).
3. If a pre-commit hook regenerates files, `git add -A` and commit AGAIN (a new
   commit, not `--amend`). If a host-side pre-commit hook fails on unrelated
   tooling (e.g. a generator needing a python dep you lack), `--no-verify` is
   acceptable - say so in the commit body.
4. `git push`.

## Verify

- No markers anywhere: `! git grep -n -e '^<<<<<<<' -e '^>>>>>>>' -e '^======='`
- No unmerged files: `git diff --name-only --diff-filter=U` is empty.
- Version coherence: every version source for a package shows the new number.
- Both feature sets survived (grep the merged enums/schema for each side's addition).
- Tests green; `gh pr view <N> --json mergeable` -> `MERGEABLE`.
