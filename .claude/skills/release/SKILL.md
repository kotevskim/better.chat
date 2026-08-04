---
name: release
description: Publish a new Better.Chat version — bump APP_VERSION, version commit, annotated tag, flip back to edge, push with tags, generate release notes since the last release, create the GitHub release. Fully automatic; requires a clean working tree.
---

Publish a new Better.Chat release from the repo root. Run **fully automatically** —
no pausing for confirmation between steps (the user opted into automatic push and
release creation). Report a summary at the end.

## Preflight — abort on any failure, change nothing

1. `git status --porcelain` must be **empty**. If anything is uncommitted, abort:
   list the dirty files and tell the user to commit them first as small, focused
   commits per the AGENTS.md commit rules. **Never commit their changes for them.**
2. Current branch must be `main` (`git rev-parse --abbrev-ref HEAD`).
3. `git pull --ff-only` — abort if it can't fast-forward.
4. `PREV=$(git describe --tags --abbrev=0)` (e.g. `v17`) → the new version `N` is
   that number + 1. Abort if tag `v<N>` already exists.
5. `git log $PREV..HEAD --oneline` must be non-empty — otherwise there is nothing
   to release.

## Release

6. In `index.html`:
   - set `const APP_VERSION = "<N>";` (it is `"edge"` between releases),
   - prepend to the `RELEASES` array (newest first):
     `{ v: "<N>", url: "https://github.com/kotevskim/better.chat/releases#release-v<N>" },`
7. Commit both edits. First line **exactly**:
   ```
   version <N> https://github.com/kotevskim/better.chat/releases#release-v<N>
   ```
   then a blank line, then a bullet list summarizing every change since `$PREV` —
   read the actual commit messages **and** diffs (`git log $PREV..HEAD`,
   `git diff $PREV..HEAD`), don't guess. Client-perspective wording.
8. Tag **annotated** (a lightweight tag would make GitHub title the release after
   the long commit headline): `git tag -a v<N> -m "v<N>"`
9. Flip back to edge: set `APP_VERSION = "edge"` again and commit as
   `back to edge after v<N>` (untagged `main` builds must show `edge` in the footer).
10. Push everything in one go: `git push --follow-tags`

## Release notes + GitHub release

11. Generate release-notes markdown covering **everything from `$PREV` to `v<N>`**:
    heading `## Better.Chat — v<N>`, sections **New / Improved / Fixed** (omit a
    section if empty), based on the commit messages and code changes. End with an
    install/update line for the Docker channel:
    `Docker: docker pull ghcr.io/kotevskim/better.chat:v<N>` (also available as
    `:latest`). Include the markdown in the chat reply too, so the user has it
    either way.
12. Create the GitHub release — first check the CLI:
    - `gh auth status` succeeds → write the notes to a temp file and run
      `gh release create v<N> --title "v<N>" --notes-file <file>`
    - `gh` missing or unauthenticated → skip, print the notes, and point the user
      to https://github.com/kotevskim/better.chat/releases/new?tag=v<N>
      (title must be `v<N>`).
13. Final report: version, the two commit hashes, tag pushed, release URL
    (`https://github.com/kotevskim/better.chat/releases/tag/v<N>`), and a note that
    `bc-update` now resolves `v<N>` (raw CDN may lag ~5 min) and that the tag push
    also triggered the `docker` workflow — `ghcr.io/kotevskim/better.chat:v<N>`
    and `:latest` appear on GHCR once it finishes (~2 min).
