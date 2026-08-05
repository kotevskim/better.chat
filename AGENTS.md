# Agent instructions — better.chat

Single-file web client for Rocket.Chat (`index.html`) + local proxy
(`docker/proxy.py`). No build step; `index.html` is both source and artifact.
Distributed as a Docker image (`docker/Dockerfile`, published to
`ghcr.io/kotevskim/better.chat` by `.github/workflows/docker.yml` on tag/main pushes).

## Commit messages (every commit)

- **Never commit on your own.** Commit only when the user explicitly asks
  ("commit", "commit this", …) — finishing a change, however complete, is not
  permission to commit it. (`/release` is the exception: the user invoking it IS
  the ask, and it still refuses to touch uncommitted work.)
- First line: a short summary of the change.
- Then a blank line and bullets with the details.
- If the change affects what users see or do (UI/UX), describe that effect in the
  bullets too — client-perspective wording, not implementation-speak.
- Keep commits small and focused: one feature/fix per commit. The `/release` skill
  refuses to run with uncommitted changes, so work must land as proper commits first.
- No `Co-Authored-By: Claude …` (or any co-author) trailers.

## After finishing a feature / improvement

Ask the user whether the welcome tour (the `tourSlides()` slides in `index.html`,
also shown via avatar menu → Welcome Tour) should be updated to cover it. The
same applies to visual changes — the tour's mockups imitate the real UI, so a
restyled element may make a slide stale. Just ask — don't update the tour
unprompted. Skip the question for fixes and internal changes users wouldn't
notice.

## Releases

Publishing a version is fully automated by the `/release` skill
(`.claude/skills/release/SKILL.md`): version from the last tag, bump of
`APP_VERSION` + `RELEASES` in `index.html`, version commit, annotated `v<N>` tag,
flip back to `"edge"`, `git push --follow-tags`, release notes since the previous
release, and the GitHub release via `gh`. Between releases `APP_VERSION` stays
`"edge"` (non-numeric values display without the `v` prefix), so untagged `main`
builds label themselves `edge` in the footer.
