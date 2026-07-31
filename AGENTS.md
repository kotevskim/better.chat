# Agent instructions — better.chat

Single-file web client for Rocket.Chat (`index.html`) + local proxy (`proxy.py`) +
installer (`setup.sh`). No build step; `index.html` is both source and artifact.

## "Commit and bump a version"

When the user asks to *commit and bump a version* (in any wording), do all three:

1. **Bump the version** — edit the single constant in `index.html`:
   ```js
   const APP_VERSION = "<N>";   // bump manually per release
   ```
   It feeds both the footer label and the login-page label; touch nothing else.

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

4. **Tag** the commit:
   ```
   git tag v<N>
   ```
   `bc-update` (with no argument) resolves the newest tag via the GitHub API, so
   the release isn't visible to users until the tag is pushed — remind the user to
   push with `git push --follow-tags` (or `git push && git push --tags`).

Also generate release-notes markdown for the GitHub release when asked (heading
`## Better.Chat — v<N>`, grouped New / Improved / Fixed where it helps).
