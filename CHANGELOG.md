# Change Log

This changelog adheres to [Keep a CHANGELOG](http://keepachangelog.com/).

## [Unreleased]
## [0.99.16] - 2018-10-17
### Fixed
- Sign debian .changes files individually rather than as a glob.

## [0.99.15] - 2018-10-15
### Changed
- (RE-11600) Skip signing dmgs and msis if they're already signed.

### Added
- Add optional `:key` and `:host` params to `ship_to_rubygems` method to allow
  shipping to other rubygems hosts (e.g. Artifactory).
- Add `ship_to_internal_mirror` method as a wrapper around the newly-updated
  `ship_to_rubygems` method.
- Add `nonfinal_gem_path` param to determine where to ship nightly gems.
- (RE-11480) Add `ship_nightly_gem` task to ship gems to our internal mirror and
  to our public nightly repos.
- Add support for ubuntu-18.10-amd64 (cosmic).

### Removed
- Remove `ship_gem_to_internal_mirror` task. This was previously used to ship
  gems to our internal stickler server, but has been no-op for some time now.

## [0.99.14] - 2018-09-26
### Fixed
- Signed packages now get rsync'd back to the root directory they were
  originally staged in.
- Added quotes around the `PACKAGING_LOCATION` environment variable that gets
  exported during remote bundle installs.

## [0.99.13] - 2018-09-12
### Fixed
- Don't run `has_sig?` for AIX packages.

## [0.99.12] - 2018-09-11
### Added
- Export `PACKAGING_LOCATION` before doing remote bundle installs. Must be set to
  a git branch and will fail if set to a local directory.

### Changed
- Use lowercase boolean constants.
- Move rpm `sign_all` method into Pkg::Sign::Rpm module.
- Updates to `has_sig?` for better testing and now checks for short gpg key rather than full.

## [0.99.11] - 2018-09-04
### Added
- (PA-2001) Add support for SLES 15.

### Changed
- Use packaging gem in uber_build job templates.

## [0.99.10] - 2018-08-14
### Changed
- Fix find_tool for Windows.
- Improve error messages for missing build targets.

## [0.99.9] - 2018-07-31
### Changed
- Dropped support for Ruby 1.9.3.
- Bumped rake dependency to ~> 12.3.
- Removed unnecessary win32console dependency.

### Fixed
- Fail messages when `project` is unset now includes the correct environment
  variable to set (`PROJECT_OVERRIDE`).

## [0.99.8] - 2018-07-12
### Changed
- 64-bit platform architectures are now listed first to maintain consistency
  when determining platform tag for noarch packages.
- Gem tasks are now always loaded, even without the `build_gem` setting, but
  gems will only be built when `build_gem` is true.

## [0.99.7] - 2018-06-19
### Changed
- Remote bundle installs now use Ruby 2.4.1

## [0.99.6] - 2018-06-11
### Changed
- '-latest' symlinks for Windows and macOS will now be created for all projects,
  not just puppet-agent.
- The `uber_ship_lite` task can now ship gems.

## [0.99.5] - 2018-05-08
### Changed
- PROJECT_OVERRIDE can now be passed in to allow packaging to run on projects
  which produce multiple package artifacts.
- Pkg::Tar now archives the working directory by default.
- Updates to remove references to old stickler server.

### Fixed
- Packages promoted to a release branch no longer cause PEZ to fail.
- When shipping packages packaging will now fetch all artifacts instead of
  relying on the artifacts specified in <sha>.yaml so that projects with
  multiple packages can be shipped together.

## [0.99.4] - 2018-04-17
### Added
- Added platform support for:
   * Debian 10 'Buster'
   * Ubuntu 18.04 'Bionic'
   * Fedora 28
- Added `is_legacy_repo?` helper to determine if files should be shipped to
legacy or current path structures.
- Added `yum_repo_name` and `apt_repo_name` helper methods which allows us
to maintain compatibility with projects that don't set`Pkg::Config.repo_name`
but rather set `Pkg::Config.yum_repo_name` and `Pkg::Config.apt_repo_name`.
- Fail if nonfinal_repo_name is unset for nonfinal repos.
- Added option for user to specify which directory of packages they want to sign.

### Changed
- Use `tar` labeled nodes to build tarballs
- Use `ppc` in AIX artifact paths by updating the `parse_platform_tag` function.
- Renamed redhat-fips platform to redhatfips.

### Fixed
- Fix nightlies path so we can pass a `nonfinal` variable through when we're working on
a nightly ship so we don't need to rely on the magic checking of whether or not
this is a final version.
- Copy pasta error where we were syncing the latest directory instead of the file.
- Skip tarball signing if signature already exists.

## [0.99.3] - 2018-03-15
### Added
 - Initial support added for Puppet Enterprise release branches.

### Fixed
 - (CPR-521) When building dmgs, explicitly set the filesystem type to 'HFS+'.
 - Some maintenance and cleanup of repository update logic.
 - No longer sign noarch packages multiple times.
 - Only link noarch packages to supported and tested architecture directories.
 - Only update the repository we're shipping to during yum repository updates.
 - Some maintenance and cleanup of package shipping logic.
 - Some maintenance and cleanup of package signing logic.
 - Some maintenance and cleanup of package retrieval logic.
 - Update `sign_tar` to sign all retrieved tarballs, not only tarballs for final
   tagged versions.
 - Update `sign_gem` to sign all retrieved gems, not only gems for final tagged
   versions of the expected project name. This is helpful if a single project
   creates multiple gems.
 - Fail explicitly if the package signing commands fail.

### Changed
 - Updated to new Solaris 11 signing certs.

## [0.99.2] - 2018-02-14
### Fixed
 - `FOSS_ONLY` mode was failing to fetch source tarballs.
 - Fix a few issues relating to using `bundle exec` when calling rake tasks
   via SSH.

### Added
 - The `PLATFORM_INFO` hash has added support for Fedora 27.

## [0.99.1] - 2018-02-06
### Fixed
 - Some tidying and maintenance in the gemspec file.
 - Platform tag parsing wasn't recognizing tags for sources (el-6-SRPMS or
   ubuntu-16.04-source for example).
 - Updated to use `Pkg::Util::RakeUtils.invoke_task` instead of the deprecated
   `invoke_task`.
 - Use `bundle exec` when calling rake tasks from an SSH session so we can take
   advantage of packaging being shipped as a gem.

## [0.99.0] - 2018-01-29
### Changed
 - Packaging no longer needs to be cloned into ext/packaging of whatever project
   you're building, it now can be run as a gem! Rather than loading the rake tasks
   manually, you can now do
   ```ruby
   require 'packaging'
   Pkg::Util::RakeUtils.load_packaging_tasks
   ```
 - Between the `master` and `1.0.x` branches of packaging, there was a major
   code refactoring to enable a change to the paths we are shipping to.
   Unfortunately, with the vastness of these changes and the amount of time over
   which they occurred, we do not have accurate accounting for all of the changes.
   We attempted to keep backwards compatibility where possible, though we probably
   missed something. If you want to look more into the change set, it's available
   [here](https://github.com/puppetlabs/packaging/compare/0.6.2...0.99.0). If you
   find anything we unintentionally broke, please open a ticket
   [here](https://tickets.puppetlabs.com/browse/CPR).

## [0.6.8] - 2018-08-14
### Changed
- Remove stickler and nexus configs for gem shipping.

## [0.6.7] - 2018-07-11
### Fixed
- Retrieving with `FOSS_ONLY=true` now fetches all (non-platform-specific)
  top-level files.

## [0.6.6] - 2018-05-08
### Added
- Backported `uber_ship_lite` task.

### Changed
- Pkg::Tar now archives the working directory by default.

### Fixed
- Packages promoted to a release branch no longer cause PEZ to fail

## [0.6.5] - 2018-04-17
### Added
- Added platform support for:
   * Debian 10 'Buster'
   * Ubuntu 18.04 'Bionic'
   * Fedora 28

### Changed
- Use `tar` labeled nodes to build tarballs.
- Renamed redhat-fips platform to redhatfips.

### Fixed
- Skip tarball signing if signature already exists.

## [0.6.4] - 2018-03-14
### Added
 - Initial support added for Puppet Enterprise release branches.

### Fixed
 - (CPR-521) When building dmgs, explicitly set the filesystem type to 'HFS+'.

### Changed
 - Updated to new Solaris 11 signing certs.

## [0.6.3] - 2018-02-14
### Fixed
 - Use `Pkg::Util::RakeUtils.invoke_task` instead of the deprecated `invoke_task`.

### Added
 - Added support for macOS 10.13 (High Sierra) and Fedora 27 to the
   `PLATFORM_INFO` hash.

## [0.6.2] - 2018-01-09
### Changed
 - Don't generate repo configs for AIX since AIX doesn't support yum.
 - Update default `internal_gem_host` to artifactory instead of stickler.

## [0.6.1] - 2017-12-12
### Added
 - Added platform support for:
   * el7 aarch64
   * Fedora 26
   * SLES 12 power8
 - Improved 'Getting Started' docs in the README.
 - Added automation to help with shipping packages to s3.

### Fixed
 - Don't fail if `ext/project_data.yaml` doesn't exist since that is a
   supplemental file to `ext/build_defaults.yaml`.
 - Don't prepend a user if the `osx_signing_server` string already contains a
   user.
 - When calculating the deb destination dir, use `codename.to_s` instead of
   `codename` in case `codename` is `nil`.

### Removed
 - Removed support for the following end-of-life platforms:
   * AIX 5.3
   * Fedora 24
   * Huaweios 6
   * Ubuntu 16.10 - Yakkety

## [0.6.0]
### Added
 - Platform data is now added to the manifest yaml file.
 - Added `ppc64le` as an architecture for el-7.
 - PEZ repo promotion has been enabled for debian packages.
 - Started shipping apt, rpm, and downloads to S3 if configured.
 - Started shiping metadata from vanagon and ezbake to the builds server if the
   metadata file exists.
 - Adds a `latest` symlink that points to the latest version of a package for
   osx and windows.

### Changed
 - Default repo paths for rpm have been changed to have the repo name to be the
   root directory instead of the platform.

### Removed
 - Removes support for end-of-life platforms.

## Versions <= 0.5.0 do not have a change log entry

[Unreleased]: https://github.com/puppetlabs/packaging/compare/0.99.16...HEAD
[0.99.16]: https://github.com/puppetlabs/packaging/compare/0.99.15...0.99.16
[0.99.15]: https://github.com/puppetlabs/packaging/compare/0.99.14...0.99.15
[0.99.14]: https://github.com/puppetlabs/packaging/compare/0.99.13...0.99.14
[0.99.13]: https://github.com/puppetlabs/packaging/compare/0.99.12...0.99.13
[0.99.12]: https://github.com/puppetlabs/packaging/compare/0.99.11...0.99.12
[0.99.11]: https://github.com/puppetlabs/packaging/compare/0.99.10...0.99.11
[0.99.10]: https://github.com/puppetlabs/packaging/compare/0.99.9...0.99.10
[0.99.9]: https://github.com/puppetlabs/packaging/compare/0.99.8...0.99.9
[0.99.8]: https://github.com/puppetlabs/packaging/compare/0.99.7...0.99.8
[0.99.7]: https://github.com/puppetlabs/packaging/compare/0.99.6...0.99.7
[0.99.6]: https://github.com/puppetlabs/packaging/compare/0.99.5...0.99.6
[0.99.5]: https://github.com/puppetlabs/packaging/compare/0.99.4...0.99.5
[0.99.4]: https://github.com/puppetlabs/packaging/compare/0.99.3...0.99.4
[0.99.3]: https://github.com/puppetlabs/packaging/compare/0.99.2...0.99.3
[0.99.2]: https://github.com/puppetlabs/packaging/compare/0.99.1...0.99.2
[0.99.1]: https://github.com/puppetlabs/packaging/compare/0.99.0...0.99.1
[0.99.0]: https://github.com/puppetlabs/packaging/compare/0.6.2...0.99.0
[0.6.8]: https://github.com/puppetlabs/packaging/compare/0.6.7...0.6.8
[0.6.7]: https://github.com/puppetlabs/packaging/compare/0.6.6...0.6.7
[0.6.6]: https://github.com/puppetlabs/packaging/compare/0.6.5...0.6.6
[0.6.5]: https://github.com/puppetlabs/packaging/compare/0.6.4...0.6.5
[0.6.4]: https://github.com/puppetlabs/packaging/compare/0.6.3...0.6.4
[0.6.3]: https://github.com/puppetlabs/packaging/compare/0.6.2...0.6.3
[0.6.2]: https://github.com/puppetlabs/packaging/compare/0.6.1...0.6.2
[0.6.1]: https://github.com/puppetlabs/packaging/compare/0.6.0...0.6.1
[0.6.0]: https://github.com/puppetlabs/packaging/compare/0.5.0...0.6.0
