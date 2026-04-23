# Development

## Linting

```bash
bundle exec rake lint        # Run all linters (rubocop, erb_lint, eslint)
bundle exec rake lint:fix    # Auto-fix where possible
```

Ruby and ERB linters run directly. The JavaScript linter requires npm dependencies, so either install them locally (`npm install --legacy-peer-deps`) or run lint:js inside a container:

```bash
CONTAINER=1 bundle exec rake lint:js
```

## Unit Tests

Unit tests run inside Docker containers with a full Foreman installation. Requires Docker with compose support.

```bash
bundle exec rake test:unit:up    # Build image, start containers, install deps
bundle exec rake test:unit:ruby  # Run Ruby tests
bundle exec rake test:unit:js    # Run JavaScript tests
bundle exec rake test:unit:all   # Run all unit tests
bundle exec rake test:unit:down  # Stop and remove containers
bundle exec rake test              # Shortcut: up, test, down in one step
```

Set `FOREMAN_VERSION` to test against a specific Foreman version (default: `3.18`):

```bash
FOREMAN_VERSION=3.17 bundle exec rake test:unit:up
```

## Acceptance Tests

Acceptance tests exercise the plugin through the browser using Capybara and Selenium. They build RPMs, start a multi-container environment (Foreman + OpenVox + SSH targets + Chromium), and run tests against the real UI.

**Prerequisites:**

```bash
bundle install --with acceptance
```

The [smart_proxy_openbolt](https://github.com/overlookinfra/smart_proxy_openbolt) and [foreman-packaging](https://github.com/theforeman/foreman-packaging) repos are cloned automatically when needed.

**Running:**

```bash
bundle exec rake acceptance         # Full cycle: up, run tests, down
bundle exec rake acceptance:up      # Build RPMs, start Foreman, configure everything
bundle exec rake acceptance:run     # Run tests (requires up first)
bundle exec rake acceptance:down    # Stop containers
bundle exec rake acceptance:clean   # Full reset: stop containers, remove images and artifacts
```

The `acceptance:up` task is idempotent and can be re-run to pick up new RPM changes. It caches the Foreman Docker image per version so subsequent runs are faster.

**Watching tests in the browser:**

Set `HEADFUL=1` to disable headless mode, then open `http://localhost:7900` (password: `secret`) to watch the tests via noVNC:

```bash
HEADFUL=1 bundle exec rake acceptance:run
```

**Running a subset of tests:**

`acceptance:run` accepts `TEST=<path>` to limit which test files are loaded, and `TESTOPTS=<opts>` to forward options (e.g. `--name=/pattern/`) to the Test::Unit autorunner. Both can be combined.

```bash
# Run every test in one file
bundle exec rake acceptance:run TEST=test/acceptance/tests/settings_test.rb

# Run a single test by exact method name (any file)
bundle exec rake acceptance:run TESTOPTS='--name=test_echo_task_succeeds_on_all_targets'

# Run tests whose name matches a regex within one file
bundle exec rake acceptance:run \
  TEST=test/acceptance/tests/settings_test.rb \
  TESTOPTS='--name=/host_key/'
```

**Environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `CHROMEDRIVER_URL` | `http://localhost:4444` | Selenium WebDriver endpoint |
| `FOREMAN_BRANCH` | `<version>-stable` | Foreman git branch for unit test image (derived from `FOREMAN_VERSION`) |
| `FOREMAN_PACKAGING_REPO` | `https://github.com/theforeman/foreman-packaging.git` | Git URL for foreman-packaging (cloned automatically for RPM builds) |
| `FOREMAN_PASS` | `changeme` | Foreman login password |
| `FOREMAN_URL` | `https://foreman` | Foreman URL as seen by Chrome. Override to run tests against a live instance |
| `FOREMAN_USER` | `admin` | Foreman login username |
| `FOREMAN_VERSION` | `3.18` | Foreman version to test against |
| `HEADFUL` | unset | Set to `1` to show the browser in noVNC |
| `SELENIUM_IMAGE` | auto-detected (ARM/x86) | Selenium container image (auto-selects `seleniarm/standalone-chromium` or `selenium/standalone-chrome`) |
| `SMART_PROXY_OPENBOLT_REF` | `main` | Branch or tag to clone |
| `SMART_PROXY_OPENBOLT_REPO` | `https://github.com/overlookinfra/smart_proxy_openbolt.git` | Git URL for smart_proxy_openbolt (cloned automatically for RPM builds) |

## Building Packages

Build RPM or DEB packages locally using containers. The [foreman-packaging](https://github.com/theforeman/foreman-packaging) repo is cloned automatically:

```bash
bundle exec rake build:rpm   # Build RPM
bundle exec rake build:deb   # Build DEB
```
