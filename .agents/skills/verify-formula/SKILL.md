---
name: verify-formula
description: Verify a formula in the dgarnier/homebrew-plasma tap end-to-end before pushing — build, bottle, test, audit, and Linux. Use when adding or changing any formula in this tap, when a CI run failed and needs diagnosing, or when asked to check that a formula actually works.
---

Verify a formula in this tap the way CI will, locally, before pushing. Each CI round
trip costs ~4 minutes plus queueing; most failures here are catchable in ~3.

Run the steps in order. **Stop at the first failure and fix it** — later steps assume
earlier ones passed.

## 0. Know what you are verifying

Read `AGENTS.md` at the repo root first. It lists the formula-specific rules that are
load-bearing (`env :std` on `m3dc1`, the `pumi` 2.2.x pin, no ParMETIS, and so on).
Breaking one of those produces a build that looks fine and computes garbage.

## 1. Style

```sh
brew style --fix <formula>
```

This also runs `shfmt` and `shellcheck` over shell scripts in the tap. If `shellcheck`
is not installed those checks **silently skip** and CI will fail instead — install it:

```sh
brew install shellcheck
```

## 2. Build the way CI builds

Do **not** use `--build-from-source`. It skips bottling, which has its own failure
modes (rpath rewriting, relocatability) and has reached CI unnoticed before.

```sh
brew uninstall --force <formula>
brew install --build-bottle <formula>
brew bottle --verbose --json <formula>
```

Expect a `cellar: :any`-style line and a written `.bottle.json`. A failure like
`Failed changing rpath in ...` means too many/too long `LC_RPATH` entries for
`install_name_tool` to rewrite for relocation — on macOS, drop the explicit rpaths
(absolute `install_name`s make them unnecessary there).

Clean up the artefacts afterwards: `rm -f ./*.bottle.*`.

## 3. Test — and make the test worth passing

```sh
brew test <formula>
```

Before trusting a pass, read the `test do` block and ask: **would this fail if the
program produced wrong answers?** For scientific codes the answer is often no.
`assert_path_exists` on an output file is not evidence of a working build — these codes
exit 0 and write a stub file after a failed solve.

A good test asserts on: absence of divergence/error markers in the output, a clean
completion marker, and a plausible output size. If you are changing a formula whose
test only checks for file existence, strengthen it as part of the change.

## 4. Audit

```sh
brew audit --online --skip-style <formula>
```

`--online` is the part that catches an unreachable `homepage`, which has failed CI here
before. If the failure is the known open-mpi flat-namespace one, add the formula to
`audit_exceptions/flat_namespace_allowlist.json` rather than fighting it.

## 5. Linux

Most failures in this tap are Linux-only. This is the highest-value step:

```sh
docker/test-linux.sh <formula>
```

It runs the same `brew test-bot --only-formulae` step as the ubuntu-24.04 CI leg. Read
the verdict line (`PASSED:` / `FAILED:`), not the exit status — `brew test-bot` can
print `Warning: 1 failed step ignored!` and still exit 0.

Common Linux-only failures and their fixes:

| Symptom | Cause and fix |
|---|---|
| `error while loading shared libraries: libfoo.so.N` | Bare `SONAME`, no rpath. Add `-Wl,-rpath,#{lib}` to the test link (and to the formula's own link line if it links tap libraries). |
| `The homepage URL ... is not reachable` | Flaky upstream page; use the source repo URL. |
| Undefined math symbols / missing `-lm` | Linux's linker is strict where macOS is not. |
| `TypeError: Block parameter 'block' ... got NilClass` | A `Stdenv` method needing a block (e.g. `ENV.deparallelize`) called without one under `env :std`. |

## 6. Then push

- New formula: commit subject **exactly** `<formula> (new formula)` — the bottle
  workflow parses it. Otherwise `<formula>: <description>`.
- Open a PR, wait for all four platforms, then label `pr-pull` to build bottles.
- **Poll the run you just triggered.** Do not announce "CI is running" and walk away.
- The matrix has no `fail-fast: false`, so one Linux failure cancels the macOS legs —
  a red macOS job may only be a cancellation. Confirm before diagnosing it.
- If a push does not seem to trigger a run, close and reopen the PR.

## Diagnosing a failed CI run

```sh
gh pr checks <n>
gh run view --log-failed <run-id> | grep -iE "error|FAILED|offense|SC[0-9]{4}"
```

If `--log-failed` is unhelpful, fetch the job log directly — it carries the context
that the filtered view drops:

```sh
gh api repos/dgarnier/homebrew-plasma/actions/jobs/<job-id>/logs | sed 's/\x1b\[[0-9;]*m//g'
```

Reproduce the failure locally (steps 2–5) before pushing a fix, and re-verify in the
same environment that failed.
