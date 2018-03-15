# Change Log

This changelog adheres to [Keep a CHANGELOG](http://keepachangelog.com/).

## [Unreleased]

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

[Unreleased]: https://github.com/puppetlabs/packaging/compare/0.99.3...HEAD
[0.99.3]: https://github.com/puppetlabs/packaging/compare/0.99.2...0.99.3
[0.99.2]: https://github.com/puppetlabs/packaging/compare/0.99.1...0.99.2
[0.99.1]: https://github.com/puppetlabs/packaging/compare/0.99.0...0.99.1
[0.99.0]: https://github.com/puppetlabs/packaging/compare/0.6.2...0.99.0
[0.6.4]: https://github.com/puppetlabs/packaging/compare/0.6.3...0.6.4
[0.6.3]: https://github.com/puppetlabs/packaging/compare/0.6.2...0.6.3
[0.6.2]: https://github.com/puppetlabs/packaging/compare/0.6.1...0.6.2
[0.6.1]: https://github.com/puppetlabs/packaging/compare/0.6.0...0.6.1
[0.6.0]: https://github.com/puppetlabs/packaging/compare/0.5.0...0.6.0
