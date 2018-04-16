# Change Log

This changelog adheres to [Keep a CHANGELOG](http://keepachangelog.com/).

## [Unreleased]

## [0.6.5] - 2018-04-16
### Added
- Added platform support for:
   * Debian 10 'Buster'
   * Ubuntu 18.04 'Bionic'
   * Fedora 28

### Changed
- Use `tar` labeled nodes to build tarballs
- Renamed redhat-fips platform to redhatfips.

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

[Unreleased]: https://github.com/puppetlabs/packaging/compare/0.6.5...master
[0.6.5]: https://github.com/puppetlabs/packaging/compare/0.6.4...0.6.5
[0.6.4]: https://github.com/puppetlabs/packaging/compare/0.6.3...0.6.4
[0.6.3]: https://github.com/puppetlabs/packaging/compare/0.6.2...0.6.3
[0.6.2]: https://github.com/puppetlabs/packaging/compare/0.6.1...0.6.2
[0.6.1]: https://github.com/puppetlabs/packaging/compare/0.6.0...0.6.1
[0.6.0]: https://github.com/puppetlabs/packaging/compare/0.5.0...0.6.0
