---
name: edge-updates
description: Refresh the "Edge updates" popup — summarize the client-visible changes landed on main since the last release tag and write them into the EDGE_UPDATES block in index.html, so the edge label in the footer shows what's new in the app. UI changes only; docs, Docker and proxy work are skipped. Incremental and safe to re-run daily; requires a clean working tree.
---

Refresh the **Edge updates** popup — the list behind the `edge` label in Better.Chat's
bottom-left corner. Run from the repo root, **fully automatically**, and report a
summary at the end.

The popup answers one question for someone running an untagged `main` build: *what
has landed since the last release?* This skill keeps that list current. It is
designed to be re-run — today, tomorrow, after every few commits — and only ever
writes up commits it has not written up before.

## The data it maintains

One block in `index.html`, just below the `RELEASES` array:

```js
const EDGE_UPDATES = { through: "", entries: [] };
```

- **`through`** — full sha of the newest commit already summarized. This is the
  high-water mark that makes re-runs incremental. Empty means "nothing summarized
  yet; start from the last release tag".
- **`entries`** — newest group first: `{ date: "YYYY-MM-DD", items: ["…", "…"] }`.

`/release` resets this block to `{ through: "", entries: [] }` in the same commit
that flips `APP_VERSION` back to `"edge"`, so each release cycle starts empty.

## Preflight — abort on any failure, change nothing

1. `git status --porcelain` must be **empty**. If anything is uncommitted, abort:
   list the dirty files and tell the user to commit them first as small, focused
   commits per the AGENTS.md commit rules. **Never commit their changes for them.**
2. Current branch must be `main` (`git rev-parse --abbrev-ref HEAD`).
3. `PREV=$(git describe --tags --abbrev=0)` — the newest release tag (e.g. `v21`).

## Work out what is actually new

4. Read `EDGE_UPDATES.through` out of `index.html`.
5. Pick the range:
   - `through` is empty → `RANGE=$PREV..HEAD`
   - `through` is set and still valid → `RANGE=<through>..HEAD`
   - `through` is set but **stale** — the sha is unknown to the repo, or it is not
     an ancestor of HEAD (`git merge-base --is-ancestor <through> HEAD` fails), or
     it is older than `$PREV` (history was rewritten, or a release happened since)
     → fall back to `RANGE=$PREV..HEAD` and **rebuild `entries` from scratch**
     rather than appending to a list that no longer matches the range. Say so in
     the final report.
6. List the commits: `git log $RANGE --format='%H %s'`. **Drop** any commit whose
   subject starts with `edge updates:` or `back to edge after` — version
   bookkeeping, not product changes. (`$PREV..HEAD` always contains a
   `back to edge after v<N>` commit: `/release` tags the version commit and then
   flips back to edge, so that flip sits just past the tag every cycle.)
7. If nothing survives step 6, stop here: **make no edit and no commit**, and
   report that the popup is already up to date.

## Write the entries

8. Read the real changes — `git log $RANGE` for the messages **and**
   `git diff $RANGE -- index.html` for what actually changed. Don't summarize from
   subject lines alone; they undersell multi-part commits.
9. **Only what is visible in the client.** This popup is read inside Better.Chat by
   someone using it, so a bullet has to describe something they can see or do in the
   app — a screen, a control, a keyboard shortcut, a behaviour that changed. Work
   from the `index.html` diff; a change is in scope only if it shows up there.
   Everything around the app is **out of scope and gets no bullet, however
   substantial the commit**:
   - `README.md` and any other docs
   - `Dockerfile`, `.dockerignore`, packaging, install and update instructions,
     published images
   - `docker/proxy.py` — its console output, ports and banners are not the client UI
   - `.github/` workflows, `.claude/` skills, build and release tooling
   A commit that touches both sides gets a bullet for its `index.html` half only. A
   commit that touches none of `index.html` gets nothing — that is the normal
   outcome for infrastructure work, not a sign the skill missed something.
10. Turn what is left into **client-perspective** entries: what a person using
    Better.Chat would notice, not the mechanics.
    - **One entry per feature, not per commit and not per change.** The unit is
      what a user would name if asked what's new — "you can resize chat windows
      now". A feature built over five commits is still one entry; several commits
      collapse into one, and a refactor behind unchanged UI produces none.
    - Only when a feature genuinely has a couple of distinct things worth calling
      out, use `{ text: "…", sub: ["…", "…"] }` and keep sub-points to two or
      three. Otherwise a plain string.
    - **Leave out the mechanics.** Which preset lights up, how state is stored,
      what a helper is named, why an edge case behaves as it does — cut it. If a
      line only makes sense to someone who read the diff, it doesn't belong.
    - Match the voice of the existing release notes — plain, concrete, no version
      numbers or shas, no trailing full stops on short entries.
11. Group by **commit date** (`%ad`, `--date=short`), newest group first, so a
    daily run appends one dated group. If a group for that date already exists in
    `entries`, **append the new bullets to it** instead of adding a second group
    with the same date.
12. Before writing, re-read the bullets already in `entries` and drop anything that
    restates one of them. The `through` marker prevents re-reading old commits, but
    a reworded follow-up commit can still describe a change that is already listed.
13. Set `through` to `git rev-parse HEAD` — the sha as of **before** this skill's
    own commit. Step 6's filter is what keeps that commit out of the next run.
    Do this **even when step 9 left you with no bullets at all** — the range really
    has been read, and re-reading those commits every future run would be waste.

## Commit

14. Commit `index.html` alone. Subject **exactly**:
    ```
    edge updates: <YYYY-MM-DD>
    ```
    (today's date), then a blank line and a one-line note of how many bullets were
    added and the range covered. The `edge updates:` prefix is load-bearing —
    step 6 filters on it. A run that added no bullets still commits, moving `through`
    alone; say so in the message (`0 bullets — nothing client-visible in range`).
15. Do **not** push and do **not** tag. This is a `main`-local bookkeeping commit;
    the user pushes it with their next batch, or `/release` carries it along.

## Report

16. Final report: the range covered, how many commits were summarized and how many
    were filtered out, the bullets added, the new `through` sha, and the commit
    hash. Name any commits that were read but produced no bullet because they never
    touched the client, so it is clear they were considered and not missed. If step 5
    hit the stale-marker fallback, say that `entries` was rebuilt
    from `$PREV` rather than appended to.
