# How to Release

## Version locations

The version is maintained in two files:

1. `lib/foreman_openbolt/version.rb` -- the gem version (authoritative source)
2. `package.json` -- the npm package version (must match)

If the minimum Foreman version changes, also update:

3. `lib/foreman_openbolt/engine.rb` -- `requires_foreman '>= X.Y.Z'`
4. `.github/workflows/build.yml` -- default `foreman_version` and `foreman_packaging_ref` inputs

## Release steps

1. Go to [Actions > Prepare Release](../../actions/workflows/prepare_release.yml) and run the workflow with the version to release (e.g. `1.2.0`)
2. The workflow bumps the version in `version.rb` and `package.json`, generates the changelog, and opens a PR with the `skip-changelog` label
3. Review and merge the PR
4. Go to [Actions > Release](../../actions/workflows/release.yml) and run the workflow with the same version
5. The release workflow:
   - Verifies the version in `version.rb` matches the input
   - Creates and pushes a git tag
   - Builds the gem
   - Creates a GitHub Release with auto-generated notes and the gem attached
   - Publishes the gem to GitHub Packages
   - Publishes the gem to RubyGems.org (requires the `release` environment)
   - Verifies the gem is available on RubyGems.org

## RPM/DEB packaging

After the gem is published to RubyGems, both RPM and DEB packages need to be updated in [theforeman/foreman-packaging](https://github.com/theforeman/foreman-packaging).

A bot automatically creates PRs against the `rpm/develop` and `deb/develop` branches to pick up the new gem version. These PRs build packages for Foreman nightly.

For stable Foreman releases, cherry-pick the packaging commits from the develop branches into the corresponding stable branches. The `backport` rake task automates this for all supported versions:

```bash
rake backport
```

This will:
1. Determine the supported Foreman version range (from `engine.rb` and the latest Foreman release tag)
2. Clone `foreman-packaging` with your fork as `origin` (detected via `gh auth`)
3. Find the latest `smart_proxy_openbolt` and `foreman_openbolt` bump commits on `rpm/develop` and `deb/develop`
4. For each supported version, create a cherry-pick branch, apply both commits, and push to your fork
5. If `gh` is available and authenticated, create PRs against `theforeman/foreman-packaging`

The task requires `gh` to be authenticated with a classic token that has the `public_repo` scope, or a fine-grained token with `read:org` access to `theforeman` and push access to your fork.

You can override the GitHub username with `GITHUB_USER=<username> rake backport`.

PRs against stable branches should be labeled "Stable branch".

**Alternative: manual version bump**

If the cherry-pick doesn't apply cleanly, you can bump the version manually on the stable branch instead.

*RPM:* Checkout the target branch and run `bump_rpm.sh`:
```bash
cd foreman-packaging
git checkout rpm/3.18
git checkout -b bump_rpm/rubygem-foreman_openbolt
./bump_rpm.sh packages/plugins/rubygem-foreman_openbolt
# Review changes, push to your fork, and open a PR targeting rpm/3.18
```

*DEB:* Checkout the target branch and update these files:
- `debian/gem.list` -- new gem filename
- `foreman_openbolt.rb` -- new version
- `debian/control` -- dependency versions (if changed)
- `debian/changelog` -- add a new entry

```bash
git checkout deb/3.18
git checkout -b bump_deb/ruby-foreman-openbolt
# Make the changes above, push to your fork, and open a PR targeting deb/3.18
```
