# CLAUDE.md

A Rails app for managing house concerts: shows, artists, venues, invitations and RSVPs. See `README.md` for features and `INFRASTRUCTURE.md` for hosting, email (Amazon SES) and Cloudflare.

## Stack

- Rails 8.1, MySQL (`database.yml`; `DB_HOST` defaults to `localhost`)
- Ruby 3.3 in production, `.ruby-version` (4.0.x) in development. Code must run on 3.3: CI tests both, and RuboCop targets 3.3.
- No JS/CSS build step: importmap-rails for JavaScript, dartsass-rails for SCSS. `package.json` only holds lint and format tools.
- Admin UI is Madmin, mounted at `/backstage/`. App-specific changes to Madmin are in `config/initializers/madmin.rb` (`MadminPatches`) and `app/madmin/`.
- Admin sign-in uses Devise, plus passkeys from devise-webauthn (`Admins::PasskeysController`).

## Commands

```sh
bin/dev                          # server + dartsass watcher
bin/rails test                   # unit, integration, controller tests
bin/rails test:system            # system tests
bundle exec rubocop --parallel   # Ruby lint (whole codebase)
npm run lint:css                 # SCSS lint (Stylelint)
npm run lint:js                  # ESLint
npm run format:check             # Prettier (app/javascript)
git ls-files -z '*.html.erb' | xargs -0 bundle exec htmlbeautifier --lint-only --keep-blank-lines 1
```

## Linting

Lint before every commit. CI runs all of these and fails on any offense.

- **Ruby:** lint all code with RuboCop (`bundle exec rubocop --parallel`), not just the files you changed, and fix every offense. Config: rubocop-rails-omakase plus rubocop-performance, rubocop-rails and rubocop-rake.
- **SCSS:** lint `app/assets/stylesheets` with Stylelint (`npm run lint:css`; `npm run format:css` autofixes).
- **JavaScript:** ESLint and Prettier.
- **ERB:** htmlbeautifier, keeping at most 1 blank line in a row.

`.pre-commit-config.yaml` runs these hooks, plus whitespace and end-of-file fixers, using the versions locked in `Gemfile.lock` and `package-lock.json`.

## Code guidelines

- Prefer a framework or gem's extension points (hooks, subclass overrides, config) over monkey patching. If a patch can't be avoided, prepend a named module (as `MadminPatches` does) and comment why it's needed. Copy a whole gem template (e.g. a Madmin view) only when neither works.
- When working around a bug in a gem, say so in a comment that names the gem version, so the workaround can be removed once it's fixed upstream.
- Comments describe what the code does now and why. No history (“used to”, “previously”); that belongs in commit messages.
- Write Ruby methods as `def … end`, never endless `def x = …` (RuboCop enforces this).
- End JavaScript statements with semicolons, including in generator output (ESLint and Prettier enforce this).
- Normalize input in the model (`normalizes`) instead of in each caller.
- After fixing a bug that belongs to a class of defect, search the codebase for other instances and fix them too.

### User-facing text

- User-facing text goes in `config/locales/*.yml`. Use typographic quotes and apostrophes (“ ” ’).
- Name the email address a message is about, e.g. “this email address (jane@example.com)”.
- Make link and button text describe the action. No “click here”.
- Example data in code, tests, commits and PRs uses placeholders (Jane Smith, jane@example.com), never real people’s names.
- Check new or changed pages and emails at 375px wide. Madmin table cells don’t wrap, so hide columns that would overflow with the `hide-on-phone` class.

## Product decisions

- Mailing-list signup is single opt-in: new addresses are added immediately. Don’t propose double opt-in. The resulting signup enumeration is an accepted risk.
- Don’t add code for existing records that fail newer validations (e.g. `save(validate: false)` workarounds).
- Manual send buttons and `next_show:*` rake tasks are limited to `Show.next` (`next_show?`) to avoid sending the wrong show’s email. Automated per-show jobs skip this check.

## Tests

- Minitest with fixtures (`test/fixtures`). Integration tests are in `test/integration`, browser tests in `test/system`.
- Every behavior change gets tests. Bug fixes get a test that would have caught the bug. Skip tests for one-line declarative changes, such as a Madmin attribute option.
- CI has no `RAILS_MASTER_KEY`, so `Rails.application.credentials` is empty there. Test credential-dependent code with `config/master.key` moved aside, and prefer `ENV["X"].presence || Rails.application.credentials.dig(...)`.
- Don’t use `Object#stub`: on Minitest 6 it silently does nothing on objects with `delegate_missing_to`, such as credentials. Set `ENV` values in `setup` and restore them in `teardown` instead.
- If you can't run the tests (e.g. no database access), say so. Don't claim they pass.

## Review

Before committing, run `/code-review` and `/simplify` on the changes. Fix what they find, or note why a finding was skipped.

Also run `/security-review` when a change touches security-sensitive code, including:

- authentication: Devise, passkeys, sessions, trusted devices, password resets
- authorization and the admin area (`/backstage/`)
- handling of untrusted input: params, file uploads and imports, the SES events endpoint (`POST /ses`)
- credentials, secrets or `filter_parameter_logging`
- rate limiting (`rack_attack.rb`) and outbound email or SMS

## Git

- **Commit only when asked.** Stop with the changes uncommitted, run the reviews above, then ask.
- **Branches:** name branches `fix/…` or `feat/…`, e.g. `fix/passkey-flash-names`, `feat/calendar-feed`. Use another Conventional Commits type (e.g. `test/`, `docs/`) only when neither fits. Don't commit directly to `main`.
- Create branches with `git switch -c X --no-track origin/main`, so a branch never has `main` as its upstream.
- Sync branches with `git rebase`, never `git merge`.
- **Commits:** use Conventional Commits (`type: summary`, or `type(scope): summary`). The `conventional-pre-commit` hook and CI enforce this. Types in use: `feat`, `fix`, `test`, `build`, `chore`, `style`, `refactor`, `docs`.
- Split work into logical commits. Put tests in their own `test:` commit right after the code they cover. A test-only refactor can go first.
- Commit bodies are a few short, factual statements of what changed. No backstory.
- The pre-commit hooks can reject a commit and leave the changes staged. Check the commit's exit status and `git status` before any checkout or `git reset --hard`.
- **Pull requests:** follow `.github/pull_request_template.md` (Description, Related Issues). The title needs a Conventional Commits prefix too (CI checks it); use the main commit's subject.
