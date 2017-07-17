# Change Log

This changelog adheres to [Keep a CHANGELOG](http://keepachangelog.com/).

## [Unreleased]

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

[Unreleased]: https://github.com/puppetlabs/packaging/compare/0.6.0...HEAD
[0.6.0]: https://github.com/puppetlabs/packaging/compare/0.5.0...0.6.0
