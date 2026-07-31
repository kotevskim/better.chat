# Agent instructions — better.chat

Single-file web client for Rocket.Chat (`index.html`) + local proxy (`proxy.py`) +
installer (`setup.sh`). No build step; `index.html` is both source and artifact.

## Commit messages (every commit)

- First line: a short summary of the change.
- Then a blank line and bullets with the details.
- If the change affects what users see or do (UI/UX), describe that effect in the
  bullets too — client-perspective wording, not implementation-speak.
- Keep commits small and focused: one feature/fix per commit. The `/release` skill
  refuses to run with uncommitted changes, so work must land as proper commits first.
- No `Co-Authored-By: Claude …` (or any co-author) trailers.

## Releases

Publishing a version is fully automated by the `/release` skill
(`.claude/skills/release/SKILL.md`): version from the last tag, bump of
`APP_VERSION` + `RELEASES` in `index.html`, version commit, annotated `v<N>` tag,
flip back to `"edge"`, `git push --follow-tags`, release notes since the previous
release, and the GitHub release via `gh`. Between releases `APP_VERSION` stays
`"edge"` (non-numeric values display without the `v` prefix), so untagged `main`
builds label themselves `edge` in the footer.
