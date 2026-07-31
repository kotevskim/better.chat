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

## "Commit and bump a version"

> Automated: the `/release` skill (`.claude/skills/release/SKILL.md`) runs this whole
> flow — including push, release notes, and the GitHub release — from a clean tree.
> The steps below remain the reference for what it does.

When the user asks to *commit and bump a version* (in any wording), do all three:

1. **Bump the version** — edit the single constant in `index.html`:
   ```js
   const APP_VERSION = "<N>";
   ```
   It feeds both the footer label and the login-page label; touch nothing else.
   Between releases the constant is `"edge"` (non-numeric values display without
   the `v` prefix) — so untagged `main` builds (fresh installs, `bc-update edge`)
   show `edge` in the footer. After tagging (step 4), set it back to `"edge"` in a
   follow-up commit.

2. **Add a releases entry** — prepend the new version to the `RELEASES` array in
   `index.html` (newest first):
   ```js
   { v: "<N>", url: "https://github.com/kotevskim/better.chat/releases#release-v<N>" },
   ```
   The GitHub release for the new version may not exist yet — that's expected; it
   gets published later. Use the URL pattern above regardless.

3. **Commit** with this message format — first line exactly:
   ```
   version <N> https://github.com/kotevskim/better.chat/releases#release-v<N>
   ```
   followed by a blank line and a bullet list of the changes included in the commit
   (client-perspective wording, one line per change).

4. **Tag** the commit — annotated, with the plain version as its message:
   ```
   git tag -a v<N> -m "v<N>"
   ```
   Annotated, because a lightweight tag has no message of its own: GitHub then
   titles the release after the commit headline (the long `version <N> https://…`
   line). The release title should be typed as `v<N>` in the form regardless.
   `bc-update` (with no argument) resolves the newest tag via the GitHub API, so
   the release isn't visible to users until the tag is pushed — remind the user to
   push with `git push --follow-tags` (or `git push && git push --tags`).

5. **Generate release-notes markdown** for the GitHub release — always, in the
   same reply as the commit (don't wait to be asked): heading `## Better.Chat — v<N>`,
   grouped New / Improved / Fixed where it helps.
