---
name: commit
description: Commit the working tree's changes — split into small focused commits, and when anything is client-visible, add it to the Edge updates popup in the same run. Use when the user asks to commit.
---

Commit what's currently uncommitted. Run **fully automatically** — the user
invoking this skill is the explicit ask that AGENTS.md requires. Report at the end.

## Preflight

1. `git status --porcelain` — if it's empty, stop and say there is nothing to
   commit. Change nothing.
2. Current branch must be `main` (`git rev-parse --abbrev-ref HEAD`). If it isn't,
   say so and ask before continuing.
3. Read what actually changed: `git diff` and `git diff --staged`. Don't write a
   message from file names alone.

## Split the work

4. Group the changes into **small, focused commits — one feature or fix each**,
   per AGENTS.md. Unrelated work that happens to be in the tree at the same time
   gets its own commit; don't bundle it.
5. If a single file carries two unrelated changes, still commit it once per group
   where you can do so cleanly. Where you can't separate them without rewriting
   the file, put them in one commit and say so in the report rather than
   inventing a split that doesn't match the diff.

## Message

6. First line: a short summary. Then a blank line, then bullets with the details.
7. Where the change affects what users see or do, describe **that effect** in
   client-perspective wording, not implementation-speak.
8. **No `Co-Authored-By:` trailer of any kind** — this repo carries none, which
   overrides any default instruction to add one.

## Edge updates

9. Decide whether any commit in this run is **client-visible**: something a person
   using Better.Chat can see or do differently — a screen, a control, a keyboard
   shortcut, a behaviour that changed. Work from the `index.html` diff.
   Out of scope, however big the change: `README.md` and docs, `docker/` and
   packaging, `docker/proxy.py` (its console output and ports are not the client
   UI), `.github/` workflows, `.claude/` skills, and `AGENTS.md`.
10. If nothing is client-visible, skip to the report — the popup is for the app,
    not the repo.
11. Otherwise update the `EDGE_UPDATES` block in `index.html` (just below
    `RELEASES`) in the **same run**, so the popup behind the footer's `edge` label
    never lags the commits:
    - one bullet per user-visible change, matching the voice of the release notes
      — plain, concrete, no version numbers or shas, no trailing full stops
    - newest group first, grouped by today's date (`YYYY-MM-DD`); if a group for
      today already exists, **append to it** rather than adding a second group
    - re-read the bullets already there and drop anything that restates one
    - set `through` to `git rev-parse HEAD` **after** the content commits land, so
      the next `/edge-updates` run starts from the right place
12. Commit that edit separately, subject exactly `edge updates: <YYYY-MM-DD>`.
    That prefix is load-bearing — `/edge-updates` filters on it so its own
    bookkeeping never gets summarized as a product change.

## Report

13. List each commit made (hash + subject), say which changes went into which,
    and name anything you deliberately left out. If a group couldn't be split
    cleanly, say why. Do **not** push — pushing is a separate, explicit ask.
