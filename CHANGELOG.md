# Change Log

This changelog adheres to [Keep a CHANGELOG](http://keepachangelog.com/).

## [Unreleased]
### Added
- (PA-5514) Add support for Fedora 38 x86_64

## [0.113.0] - 2024-01-08
### Added
- (PA-5878) Add support for macOS 14 (Intel)
- (PA-5551) Add support for Debian 12 'bookworm'
- (PA-5904) Add support for macOS 14 ARM 64 architecture
### Removed
- (maint) Remove mk_repo command because it is no longer used.
### Changed
- (maint) some internal code cleanup to appease Rubocop

## [0.112.0] - 2023-11-16
### Added
- (PA-5568) Added platform for Amazon Linux 2023 for x86_64 & aarch64

## [0.111.0] - 2023-10-17
### Added
- (PA-4605) Add debian platform condition to handle arm architecture
- (PA-4606) Add support for Debian 11 (ARM64) architecture
- (PA-5000) Add support for Red Hat 9 (ARM64) architecture

## [0.110.1] - 2023-07-20
### Added
- (PA-4775) Add support for macOS 13 ARM 64 architecture
- (PA-4591) Add support for macOS 13 x86-64 architecture
- (maint) Add support for AIX 7.2

### Removed
- (PA-5031) Remove support for Mac OS 10.15 (x86_64).
- (PA-5043) Remove Red Hat 7 (aarch64).

## [0.110.0] - 2023-05-9
### Removed
- (RE-15479) Remove AptStagingServer module and references to it because it is no longer needed.
- (RE-15217) Remove SUSE Linux Enterprise Server 11 (i386) from PLATFORM_INFO hash.
- (RE-15221) Remove SUSE Linux Enterprise Server 11 (x86-64) from PLATFORM_INFO hash.

## [0.109.7] - 2023-04-25
### Fixed
- (maint) Update keyword argument syntax in nightly repo Rake task

### Changed
- (maint) Use ruby 3.1.1 for remote bundle installs.

## [0.109.6] - 2023-04-14
### Changed
- (RE-15419) Update internal gem host to rubygems__local

## [0.109.5] - 2023-03-21
### Fixed
- (RE-15738) The previous size choice of 200m for `hdiutil create` was too conservative.
  Increased to 500m for the moment in front of an actual fix.

## [0.109.4] - 2023-03-20
### Fixed
- (RE-15738) To prevent 'No space left on device' errors while re-creating a MacOS dmg
  with `hdiutil create` provide a size.

## [0.109.3] - 2023-03-16
### Changed
- (maint) Do not throw an error when pushing a gem to rubygems if it already has been pushed.

## [0.109.2] - 2023-03-07
### Changed
- (maint) Updated #update_ips_repo to be more resilient around location of p5p files.

## [0.109.1] - 2023-03-01
### Fixed
- (maint) Fixed a bug in the 'artifact already exists' error where the path to the artifact
  wasn't printing correctly
- (maint) Go back to old ERB.new method call to accommodate Ruby 2.5

## [0.109.0] - 2023-02-28
### Changed
- (maint) make the 'artifact already exists' error more informative.
- (maint) refactor rspec examples for Ruby 3.x compatibility.
- (maint) Rubocop compliance changes.

## [0.108.2] - 2023-02-08
### Changed
- (maint) Updated the spec tests in repo_spec to use the newer 'expect' syntax.

### Fixed
- (maint) Pkg::Rpm::Repo.ship_repo_configs was not detecting the condition with no repos
  to ship. This was causing a confusing error message later.
- (RE-15086) Don't pass `--passphrase-fd 3` with gpg >= 2.1; it's no longer provided there.

## [0.108.1] - 2023-01-04
### Changed
- (RE-15086) Stop forcing rpmsign to use gpg1

## [0.108.0] - 2022-10-04
### Removed
- (RE-14990) Start teardown of abandoned plans to migrate downloads/yum/apt/nightlys from S3 to GCP.
  Leave in place the parts that were shipping to apt.repos.puppet.com as a later step should
  we decide to move that to AWS.
- (maint) Removes deprecated platforms (Debian 9, Fedora 32 and 34, Ubuntu 16.04)

## [0.107.2] - 2022-09-20
### Changed
- (maint) Move GCP bucket names for MSI signing to params.

## [0.107.1] - 2022-08-29
### Added
- (RE-13698) Added support to ship nightly and stable debs to apt.repos.puppet.com. Introduced
  feature toggles, via the "NIGHTLY_SHIP_TO_GCP" and "STABLE_SHIP_TO_GCP" environment variables
  that will add shipping to GCP as part of the pl:jenkins:ship_nightly and pl:jenkins:ship_final
  tasks
- (PA-4444) Adds Fedora 36 to platforms
- (maint) Added support for signing RPMs using gpg >= 2.1

## [0.107.0] - 2022-06-14
### Added
- (PA-4117) Add Ubuntu 22.04
- (maint) begin AWS to GCP transition for apt, yum, nightlies and downloads by shipping
  to both AWS and GCP.

## [0.106.3] - 2022-05-03
### Changed
- (maint) Update rvm ruby version in remote bundle install to 2.7.5.
- (RE-13764) Get rvm ruby version from environment variable instead of hard coded in remote
  bundle install method.

## [0.106.2] - 2022-05-02
### Changed
- (RE-14611) Change msi sign method to use the gcp msi signer
- (RE-13764) Get rvm ruby version from environment variable instead of hard coded in remote
  bundle install method.

## [0.106.1] - 2022-04-12
### Added
- (PA-4219) Adds support for macOS 12 Monterey
- (RE-14627) Add nil handling for no-op promotions

### Changed
- (maint) Allow support for user@host for ssh to the solaris signing server
- (maint) Change to dependency of the Artifactory gem to ~> 3.0; 2.0 is very, very old.
- (maint) Updated the signing certificate for Solaris

## [0.106.0] - 2022-01-24
### Fixed
- (maint) Updated ship.rake to not ship .sha1 files to Artifactory. Artifactory has its own
  checksum method and handing it .sha1 files confuses it.

## [0.105.0] - 2022-01-06
### Removed
- EOL Platform support removals
  - (RE-14105) EL 5
  - (RE-14075) Debian 8
  - (RE-14108) Fedora 30
  - (RE-14111) Fedora 31
  - (RE-14114) OSX 10.14
  - (maint) OSX 10.13
  - (maint) Ubuntu 18.10

### Added
- (PA-4117) Add el-9 to platforms
- (PA-3614)  Add macOS 11 to platforms
- (VANAGON-165) Create methods to replace the need for invoking rake tasks in vanagon. More specifically, methods were made for fetch, load_extras, rpm_repos, deb_repos, ship, ship_to_artifactory, and sign_all.

## [0.104.0] - 2021-11-10
### Added
(RE-13941) 3rd attempt tp ship to new puppet-version based apt repos
  Broke some of the :ship tasks into smaller bits and moved them out of Rake.
  Introduced two new tasks, `pl:stage_nightly_debs` and `pl:stage_stable_debs`
  for sending debs to a staging area for repos based on puppet major version.
  The above new tasks use a required set of shims from the `apt_stage_repos` gem.

## [0.103.0] - 2021-10-14
### Fixed
- Revert back to 0.99.81 code. Updating Ruby version in the gemspec from 2.0 to 2.3
  caused some moderately obscure breakage. It's clear that we need to take a different
  direction for future feature additions.

## [0.102.0] - 2021-10-13
### Added
(RE-13941) 2nd attempt tp ship to new puppet-version based apt repos
  Broke some of the :ship tasks into smaller bits and moved them out of Rake.
  Introduced two new tasks, `pl:stage_nightly_debs` and `pl:stage_stable_debs`
  for sending debs to a staging area for repos based on puppet major version.
  The above new tasks use a required set of shims from the `apt_stage_repos` gem.

## [0.101.0] - 2021-10-06
### Changed
- Reverted 0.100.0 because of severe regression

## [0.100.0] - 2021-10-06
### Added
(RE-13941) Ship to new puppet-version based apt repos
  Broke some of the :ship tasks into smaller bits and moved them out of Rake.
  Introduced two new tasks, `pl:stage_nightly_debs` and `pl:stage_stable_debs`
  for sending debs to a staging area for repos based on puppet major version.
  The above new tasks use a required set of shims from the `apt_stage_repos` gem.

## [0.99.81] - 2021-09-17
### Added
- (PA-3768) Add RedHat 8 FIPS to platforms

### Fixed
- Fix confusion between nightlies.puppet.com and nightlies.puppetlabs.com

## [0.99.80] - 2021-08-17
### Added
- (PA-3870) Add Ubuntu 18.04 aarch64 to platforms hash
- (RE-12419) Add pl:remote:sync_apt_repo_to_gcp task for new APT repo

### Changed
- artifact download from Artifactory is a bit more verbose.

## [0.99.79] - 2021-07-27
### Added
- Add macOS 11 arm64 to platforms hash
- (PE-32530) update sign_dmg to handle multiple architectures

### Fixed
- Upload artifacts to artifactory before uploading checksums

## [0.99.78] - 2021-06-21
### Added
- (PA-3708) Add support for Debian 11 amd64

### Fixed
- (RE-14142) MacOS signing is fairly broken

## [0.99.77] - 2021-06-01
### Added
- (PA-3614)  Add macOS 11 to platforms
- (PA-3602)  Add Fedora 34 to platforms

### Changed
- (RE-11477) Remove support for cisco-wrlinux and eos as those were EOL'd for platform6.
- (RE-13479) Remove support for AIX 6.1

## [0.99.76] - 2021-03-21
### Added
- (PA-3531) Add support for RedHat 8 ppc64le
- (RE-11821) Create a configuration-validation hook after a pl:fetch

### Fixed
- `puppet-tools` and `puppet-nightly` repositories were missed in the apt path updates.
- `create_link` tasks were initially created under the wrong namespace, these
   have been moved to under the `pl` namespace.
- SHA1 signing servers were updated

### Changed
 - (PA-3358) Removed puppet 7 nightly gem rake task

## [0.99.75] - 2020-12-08
### Added
- (PA-3478) add Ubuntu 2004 aarch64 to platform hash
- (PA-3497) accommodate arm64 debian packages for aarch64

## [0.99.74] - 2020-11-19
### Changed
- Update bundle installs to use ruby 2.5.1

## [0.99.73] - 2020-10-28
### Changed
- (RE-13722) make a semi-revert of the APT repository path changes, labeling them as
  'FUTURE' changes in order to coordinate details of the changes better. This change
  is expected to reappear shortly once the downstream issues are resolved.

## [0.99.72] - 2020-10-26
### Added
- Allow `Pkg::Config.version` to be overridden with the `PACKAGING_PACKAGE_VERSION`
  environment variable.

### Changed
- Added the `--silent` flag to curl when fetching gem JSON data from rubygems.org.
  The live download progress/throughput information is noisy and not really helpful
  when packaging is running in a batch mode.
- APT repository paths are changing in puppet7 to allow for new repos for each major
  puppet version. Updated the pathing calculations for this case.

## [0.99.71] - 2020-10-02
### Fixed
- Fixed a bug in the regex for debian component from path determination

## [0.99.70] - 2020-10-01
### Added
- Added ability to determine debian component for paths containing 'main'

## [0.99.69] - 2020-09-21
### Added
- (PA-3386) Add support for Redhat 8 aarch64.

## [0.99.68] - 2020-08-11
### Added
 - (PA-3356) Add puppet 7 nightly gem rake task

### Fixed
 - (RE-13629) Do not use exact file match when downloading final PE tarballs

## [0.99.67] - 2020-07-20
### Added
- (PA-3212) Add support for Fedora 32.

### Fixed
- Pinned the 'csv' gem to 3.1.5 to avoid pulling in a version of stringio that
  depends on ruby 2.5.

## [0.99.66] - 2020-07-02
### Added
- (RE-13303) Moved rolling repo link creation from the ship tasks
  to separate rake tasks - `pl:remote:create_repo_links` and
  `pl:remote:create_nightly_repo_links`
- Update `Pkg::Paths::remote_repo_base` to support dmg, msi, and swix packaging
  types.

## [0.99.65] - 2020-06-22
### Fixed
- Add 0SX 10.13 platform back, it is not EOL for all projects.

## [0.99.64] - 2020-06-18
### Fixed
- Do not use exact match when searching for final PE tarballs.

## [0.99.63] - 2020-06-17
### Fixed
- Artifactory::Util.slice wasn't properly scoped in the `pattern_search` method.

## [0.99.62] - 2020-06-16
### Added
- (RE-13462) Mixins to allow artifactory `search` and `checksum_search` to look
  for an exact filename.

### Removed
- (RE-13273) Removed support of PC1 repos. They are obsolete.
- (RE-13177)(RE-13180)(RE-13183)(RE-13186) Removed EOL platforms and updated spec tests
  accordingly.

### Changed
- (RE-13386) In `Pkg::Artifactory` deb packages will no longer default to
  shipping to the 'pool' subdirectory.

## [0.99.61] - 2020-04-01
### Fixed
- Reverted removal of EOL platforms since it was causing breakage.

## [0.99.60] - 2020-04-01
### Added
- Added parameters to `ManageArtifactory#upload_file` to allow for setting properties
  and headers after the upload, matching the parameters in Resource::Artifact#upload.
- Added platform support for:
   * Ubuntu 20.04 'Focal'

### Fixed
- (RE-9687) Set `deb.architecture` correctly in artifactory for noarch packages.

### Removed
- (RE-13177)(RE-13180)(RE-13183)(RE-13186) Removed EOL platforms and updated spec tests
  accordingly.

## [0.99.59] - 2020-03-11
### Added
- Added the option to specify a search path to the `download_packages` artifactory
  method. If packages are found in the correct repositories but not in the
  search path, they will be copied to the search path.

### Fixed
- `debian_component_from_path` now supports the master branch.
- `debian_component_from_path` substitutes `.` and `/` with `_` so the components
   are valid.

## [0.99.58] - 2020-03-03
### Changed
- (RE-13163) Updated the signing cert and key filenames for Solaris 11 signing.

## [0.99.57] - 2020-02-18
### Added
- Add `search_with_path` artifactory method to allow you to easily access the
  Artifactory::Resource::Artifact objects matching your search criteria.

## [0.99.56] - 2020-02-11
### Changed
- (RE-13220) Removed noisy informational message when loading `platform_data`

## [0.99.55] - 2020-01-23
### Fixed
- (RE-13191) Fixed issue with the changes to MSI package signing.

## [0.99.54] - 2020-01-22
### Added
- (PA-2995) Add macOS 10.15 to platforms.

### Fixed
- Fixed the way we rsync msi packages to signing server to prevent overwriting.

## [0.99.53] - 2020-01-15
### Fixed
- (RE-13167) When checking if gem has been published, check platform as well as
  version.

### Changed
- (RE-13101) Change warning to hard fail when release-metrics update doesn't
  work.

## [0.99.52] - 2019-12-17
### Fixed
- Fixed `link_nightly_shipped_gems_to_latest` task.

## [0.99.51] - 2019-12-11
### Fixed
- Fixed a typo in the CHANGELOG.md file preventing proper linking.

## [0.99.50] - 2019-12-11
### Added
- Add windowsfips versionless symlinks.
- Add rake task to build nightly gem packages.
- Add rake task to remotely link nightly shipped gems to latest versions.

## [0.99.49] - 2019-11-19
### Fixed
- Include filename when copying PE tarballs so the parent directory is created.
- Use correct parameter name in Artifactory promotion error message.

### Added
- (PDK-1546) Add Fedora 31 to platforms
- Include target directory in output when downloading from Artifactory.

### Changed
- (RE-13072) Use artifact basename as target filename when downloading from
  Artifactory and manifest is missing filename metadata.

## [0.99.48] - 2019-11-12
### Changed
- (RE-12874) Simplify the logic for setting 'cleanup.skip' for Artifactory
  artifact directories
- Replace `Pkg::Paths.two_digit_pe_version_from_path` with
  `Pkg::Paths.debian_component_from_path` since the method was only being used
  for setting components and was not working correctly for packages populated
  to 'release' or 'feature' repos
- (RE-12869) Skip shipping gems to downloads.puppet.com, but don't exit or fail,
  when `gem_host` or `gem_path` is unset.

## [0.99.47] - 2019-10-22
### Changed
- Capture debug output when updating release-metrics.
- (RE-12868) Update timestamp server for windows signing.

## [0.99.46] - 2019-10-14
### Added
- Allow Gemfile source to be overridden with `GEM SOURCE`.
- (RE-11802) Add `update_release_metrics` task for adding a release to the
  release-metrics repo.

### Changed
- Stop testing against Ruby 2.0.0 and 2.1.9.
- Start testing against Ruby 2.6.5.

## [0.99.45] - 2019-10-08
### Fixed
- (RE-12788) Set `deb.component` property when copying enterprise packages so
  repos are properly populated.

## [0.99.44] - 2019-10-03
### Fixed
- (RE-12793) Loosen the dependency on rake to allow packaging to use rake >= 13.0.0
  at runtime.

### Added
- (RE-12727) Remove reverted packages from artifactory enterprise repositories.

## [0.99.43] - 2019-10-01
### Added
- (RE-12731) Set `cleanup.skip` property when uploading PE tarballs to
  Artifactory (and unset everwhere else) to ensure that the latest PE tarballs
  are never purged.
- (RE-12734) Add `download_final_pe_tarballs` method for downloading PE tarballs
  from Artifactory.
- (RE-12732) Add `download_beta_pe_tarballs` method for downloading PE Beta
  tarballs from Artifactory.
- (RE-12734) Add `copy_final_pe_tarballs` method for copying PE tarballs to
  the archives/releases directory on Artifactory.
- (RE-12765) Add `pattern_search` method to Artifactory gem. This is a monkey
  patch that should've been submitted upstream, but, due to Chef's recent
  contract with ICE, we don't feel comfortable contributing to their codebases
  at this time.
- (RE-12767) Add `populate_pe_repos` method for copying all packages from one PE
  version into the appropriate directory structure for a new PE version.
- (RE-12771) Add `teardown_repo` method for removing all packages that match a
  given search pattern from a given repo.
- (PA-2839) Add support for windowsfips-7-x64.

### Changed
- Include source path in output when promoting packages in Artifactory.
- Rename `update_latest_file` method to `upload_file` to be more generic.

## [0.99.42] - 2019-09-06
### Added
- (RE-12728) Add `update_latest_file` for enterprise repos on artifactory.
- (RE-12729) Add `download_artifact` to download artifact from artifactory based on name, repo, and file path.
- (PE-16465) Add functionality to create a tarball of all PE platform repos.

## [0.99.41] - 2019-09-03
### Fixed
- Always ship `.yaml` and `.json` files in `ship_to_artifactory` rake task.

## [0.99.40] - 2019-08-28
### Added
- (RE-12711) Add `package_exists_on_artifactory?` check so we don't re-ship already shipped packages to artifactory.

## [0.99.39] - 2019-08-20
### Added
- Calculate and ship md5sum for packages shipped to artifactory.

### Changed
- (RE-11765) Remove unused symlinks from the spec directory.

### Fixed
- For the release action, only publish gem if it was a tag that was created.

## [0.99.38] - 2019-08-13
### Added
- (RE-12499) Add `purge_copied_pe_tarballs` function to remove shipped PE packages from artifactory.
- Add `test` and `release` actions for the packaging gem.

## [0.99.37] - 2019-08-09
### Added
- (RE-12605) Add CODEOWNERS file.
- (RE-12499) Add function `download_packages` that uses a provided manifest to download packages from artifactory to a staging directory.
- (RE-12499) Add `ship_pe_tarballs` to upload packages to a specified artifactory repo and file path.

## [0.99.36] - 2019-07-09
### Changed
- (RE-12520) Fail shipping gems to downloads.puppet.com when `gem_path`
  is unset. Skip shipping gems to downloads.puppet.com when `gem_host` is unset.

## [0.99.35] - 2019-06-11
### Fixed
- Don't use `set -e` for windows signing. This will let retries work.

## [0.99.34] - 2019-06-05
### Changed
- Update the regular expression to skip errors both when a package already exists and
  when you don't have permissions to overwrite the existing package when deploying to
  artifactory.
- Add rake tasks to sync yum, apt, and downloads archives individually.
- Don't delete packages from rsync servers so we don't need to stand up additional archive
  hosts.

## [0.99.33] - 2019-05-29
### Added
- (PA-2678) Add support for Fedora 30.

## [0.99.32] - 2019-05-21
### Added
- (CPR-698) Add `update_archive_yum_repo` and `update_archive_apt_repo` tasks
  for updating repo metadata for release-archives.

### Changed
- (CPR-698) Stage debian packages from the freight directory, rather than from
  the pool directory, in order to create repo metadata for release-archives.

## [0.99.31] - 2019-05-13
### Added
- (RE-11598) Add `stage_archives`, `deploy_staged_archives_to_s3`, and
  `archive_cleanup` tasks for moving EOL packages to release-archives.

## [0.99.30] - 2019-04-25
### Added
- Add the ability to specify the debian repository component when
  promoting packages into artifactory.

### Fixed
- (CPR-677) We were not getting `-latest.[dmg|msi]` symlinks for nightly repositories.
  The code has been updated to account for path differences with nightly repositories.

## [0.99.29] - 2019-04-17
### Added
- (RE-10207) Add `stage_release_packages` and `stage_nightly_release_packages`
  tasks to automatically ship release packages and update symlinks to them.

### Changed
- (RE-12205) Add retries and additional time servers to MSI signing process.

## [0.99.28] - 2019-04-11
### Fixed
- Due to incorrect ordering in the checks for `nil?` and `empty?` in `all_artifact_names`,
  promotions into artifactory for anything that didn't have additional packages was (softly)
  failing. This has been fixed.

## [0.99.27] - 2019-04-10
### Fixed
- Presesrve the original tag to keep the `fedora-f` prefix in the repo config
  artifact path. We have discontinued the `-f` in recent releases but this is
  still an issue with puppet-agent 1.10.x.

## [0.99.26] - 2019-04-09
### Fixed
- Ensure existing artifact path is not nil before comparing to additional
  artifact paths.

## [0.99.25] - 2019-04-09
### Added
- (RE-9511) Record `additional_artifacts` in `platform_data` yaml output for
  projects that produce multiple packages.
- (RE-11105) Add `promote_package` method to promote (i.e. copy) packages to
  separate enterprise repositories on Artifactory.

## [0.99.24] - 2019-03-12
### Added
- (RE-12062) Copy all the build_metadata\*.json files via glob rather than a single
  static file.

### Changed
- Update ruby version exclusions for rubocop.

## [0.99.23] - 2019-01-28
### Added
- Check if a specific gem version has already been shipped to rubygems.org
  before attempting to ship the gem.

## [0.99.22] - 2019-01-22
### Changed
- (RE-11984) Add quotes and escape '\d' in the regex used to find the latest
  version of a particular project.

## [0.99.21] - 2019-01-08
### Changed
- (RE-11741) Search for '<project_name>-\d' in order to prevent aggressive
  matching when determining latest package to symlink to (e.g. prevent
  'puppet-agent' from matching a search for 'puppet').
- (RE-11741) Only create '-latest' symlinks if there were packages to ship.

## [0.99.20] - 2018-12-17
### Added
- (PA-2326) Add support for RHEL 8
- (PA-2220) Add support for macOS 10.14 (Mojave)

## [0.99.19] - 2018-12-13
### Changed
- Pin artifactory gem to ~> 2, since artifactory 3.0.0 requires ruby >= 2.3.

## [0.99.18] - 2018-11-28
### Added
- (PA-2232) Add support for Fedora 29.

### Changed
- (RE-11584) Replace `remote_bootstrap` with `remote_unpack_git_bundle`, which
  does the same thing except for actually bootstrapping or bundle installing
  packaging. Instead of bundle installing in the same method as unpacking the
  git bundle, we now bundle install as part of the same command as remote rake
  calls to ensure that all gems are accessible when we need them.

### Removed
- Remove deprecated `remote_bootstrap` method, since there is no longer
  anything using the bootstrap method of installing packaging.

## [0.99.17] - 2018-11-13
### Added
- Add `release_package_link_path` method to determine the release package
  symlink path for a given platform.

### Fixed
- (RE-11291) Improve rsync error message with more detail on how to resolve the
  error.
- (RE-11714) Update `link_name` method to take an optional `nonfinal` param to
  determine whether we want the `repo_link_target` or
  `nonfinal_repo_link_target`. Previously, we pivoted on the build version,
  which caused undesired symlink creation when final-tagged builds were shipped
  to nightlies.

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

[Unreleased]: https://github.com/puppetlabs/packaging/compare/0.113.0...HEAD
[0.113.0]: https://github.com/puppetlabs/packaging/compare/0.112.0...0.113.0
[0.112.0]: https://github.com/puppetlabs/packaging/compare/0.111.0...0.112.0
[0.111.0]: https://github.com/puppetlabs/packaging/compare/0.110.1...0.111.0
[0.110.1]: https://github.com/puppetlabs/packaging/compare/0.110.0...0.110.1
[0.110.0]: https://github.com/puppetlabs/packaging/compare/0.109.7...0.110.0
[0.109.7]: https://github.com/puppetlabs/packaging/compare/0.109.6...0.109.7
[0.109.6]: https://github.com/puppetlabs/packaging/compare/0.109.5...0.109.6
[0.109.5]: https://github.com/puppetlabs/packaging/compare/0.109.4...0.109.5
[0.109.4]: https://github.com/puppetlabs/packaging/compare/0.109.3...0.109.4
[0.109.3]: https://github.com/puppetlabs/packaging/compare/0.109.2...0.109.3
[0.109.2]: https://github.com/puppetlabs/packaging/compare/0.109.1...0.109.2
[0.109.1]: https://github.com/puppetlabs/packaging/compare/0.109.0...0.109.1
[0.109.0]: https://github.com/puppetlabs/packaging/compare/0.108.2...0.109.0
[0.108.2]: https://github.com/puppetlabs/packaging/compare/0.108.1...0.108.2
[0.108.1]: https://github.com/puppetlabs/packaging/compare/0.108.0...0.108.1
[0.108.0]: https://github.com/puppetlabs/packaging/compare/0.107.2...0.108.0
[0.107.2]: https://github.com/puppetlabs/packaging/compare/0.107.1...0.107.2
[0.107.1]: https://github.com/puppetlabs/packaging/compare/0.107.0...0.107.1
[0.107.0]: https://github.com/puppetlabs/packaging/compare/0.106.3...0.107.0
[0.106.3]: https://github.com/puppetlabs/packaging/compare/0.106.2...0.106.3
[0.106.2]: https://github.com/puppetlabs/packaging/compare/0.106.1...0.106.2
[0.106.1]: https://github.com/puppetlabs/packaging/compare/0.106.0...0.106.1
[0.106.0]: https://github.com/puppetlabs/packaging/compare/0.105.0...0.106.0
[0.105.0]: https://github.com/puppetlabs/packaging/compare/0.104.0...0.105.0
[0.104.0]: https://github.com/puppetlabs/packaging/compare/0.103.0...0.104.0
[0.103.0]: https://github.com/puppetlabs/packaging/compare/0.102.0...0.103.0
[0.102.0]: https://github.com/puppetlabs/packaging/compare/0.101.0...0.102.0
[0.101.0]: https://github.com/puppetlabs/packaging/compare/0.100.0...0.101.0
[0.100.0]: https://github.com/puppetlabs/packaging/compare/0.99.81...0.100.0
[0.99.81]: https://github.com/puppetlabs/packaging/compare/0.99.80...0.99.81
[0.99.80]: https://github.com/puppetlabs/packaging/compare/0.99.79...0.99.80
[0.99.79]: https://github.com/puppetlabs/packaging/compare/0.99.78...0.99.79
[0.99.78]: https://github.com/puppetlabs/packaging/compare/0.99.77...0.99.78
[0.99.77]: https://github.com/puppetlabs/packaging/compare/0.99.76...0.99.77
[0.99.76]: https://github.com/puppetlabs/packaging/compare/0.99.75...0.99.76
[0.99.75]: https://github.com/puppetlabs/packaging/compare/0.99.74...0.99.75
[0.99.74]: https://github.com/puppetlabs/packaging/compare/0.99.73...0.99.74
[0.99.73]: https://github.com/puppetlabs/packaging/compare/0.99.72...0.99.73
[0.99.72]: https://github.com/puppetlabs/packaging/compare/0.99.71...0.99.72
[0.99.71]: https://github.com/puppetlabs/packaging/compare/0.99.70...0.99.71
[0.99.70]: https://github.com/puppetlabs/packaging/compare/0.99.69...0.99.70
[0.99.69]: https://github.com/puppetlabs/packaging/compare/0.99.68...0.99.69
[0.99.68]: https://github.com/puppetlabs/packaging/compare/0.99.67...0.99.68
[0.99.67]: https://github.com/puppetlabs/packaging/compare/0.99.66...0.99.67
[0.99.66]: https://github.com/puppetlabs/packaging/compare/0.99.65...0.99.66
[0.99.65]: https://github.com/puppetlabs/packaging/compare/0.99.64...0.99.65
[0.99.64]: https://github.com/puppetlabs/packaging/compare/0.99.63...0.99.64
[0.99.63]: https://github.com/puppetlabs/packaging/compare/0.99.62...0.99.63
[0.99.62]: https://github.com/puppetlabs/packaging/compare/0.99.61...0.99.62
[0.99.61]: https://github.com/puppetlabs/packaging/compare/0.99.60...0.99.61
[0.99.60]: https://github.com/puppetlabs/packaging/compare/0.99.59...0.99.60
[0.99.59]: https://github.com/puppetlabs/packaging/compare/0.99.58...0.99.59
[0.99.58]: https://github.com/puppetlabs/packaging/compare/0.99.57...0.99.58
[0.99.57]: https://github.com/puppetlabs/packaging/compare/0.99.56...0.99.57
[0.99.56]: https://github.com/puppetlabs/packaging/compare/0.99.55...0.99.56
[0.99.55]: https://github.com/puppetlabs/packaging/compare/0.99.54...0.99.55
[0.99.54]: https://github.com/puppetlabs/packaging/compare/0.99.53...0.99.54
[0.99.53]: https://github.com/puppetlabs/packaging/compare/0.99.52...0.99.53
[0.99.52]: https://github.com/puppetlabs/packaging/compare/0.99.51...0.99.52
[0.99.51]: https://github.com/puppetlabs/packaging/compare/0.99.50...0.99.51
[0.99.50]: https://github.com/puppetlabs/packaging/compare/0.99.49...0.99.50
[0.99.49]: https://github.com/puppetlabs/packaging/compare/0.99.48...0.99.49
[0.99.48]: https://github.com/puppetlabs/packaging/compare/0.99.47...0.99.48
[0.99.47]: https://github.com/puppetlabs/packaging/compare/0.99.46...0.99.47
[0.99.46]: https://github.com/puppetlabs/packaging/compare/0.99.45...0.99.46
[0.99.45]: https://github.com/puppetlabs/packaging/compare/0.99.44...0.99.45
[0.99.44]: https://github.com/puppetlabs/packaging/compare/0.99.43...0.99.44
[0.99.43]: https://github.com/puppetlabs/packaging/compare/0.99.42...0.99.43
[0.99.42]: https://github.com/puppetlabs/packaging/compare/0.99.41...0.99.42
[0.99.41]: https://github.com/puppetlabs/packaging/compare/0.99.40...0.99.41
[0.99.40]: https://github.com/puppetlabs/packaging/compare/0.99.39...0.99.40
[0.99.39]: https://github.com/puppetlabs/packaging/compare/0.99.38...0.99.39
[0.99.38]: https://github.com/puppetlabs/packaging/compare/0.99.37...0.99.38
[0.99.37]: https://github.com/puppetlabs/packaging/compare/0.99.36...0.99.37
[0.99.36]: https://github.com/puppetlabs/packaging/compare/0.99.35...0.99.36
[0.99.35]: https://github.com/puppetlabs/packaging/compare/0.99.34...0.99.35
[0.99.34]: https://github.com/puppetlabs/packaging/compare/0.99.33...0.99.34
[0.99.33]: https://github.com/puppetlabs/packaging/compare/0.99.32...0.99.33
[0.99.32]: https://github.com/puppetlabs/packaging/compare/0.99.31...0.99.32
[0.99.31]: https://github.com/puppetlabs/packaging/compare/0.99.30...0.99.31
[0.99.30]: https://github.com/puppetlabs/packaging/compare/0.99.29...0.99.30
[0.99.29]: https://github.com/puppetlabs/packaging/compare/0.99.28...0.99.29
[0.99.28]: https://github.com/puppetlabs/packaging/compare/0.99.27...0.99.28
[0.99.27]: https://github.com/puppetlabs/packaging/compare/0.99.26...0.99.27
[0.99.26]: https://github.com/puppetlabs/packaging/compare/0.99.25...0.99.26
[0.99.25]: https://github.com/puppetlabs/packaging/compare/0.99.24...0.99.25
[0.99.24]: https://github.com/puppetlabs/packaging/compare/0.99.23...0.99.24
[0.99.23]: https://github.com/puppetlabs/packaging/compare/0.99.22...0.99.23
[0.99.22]: https://github.com/puppetlabs/packaging/compare/0.99.21...0.99.22
[0.99.21]: https://github.com/puppetlabs/packaging/compare/0.99.20...0.99.21
[0.99.20]: https://github.com/puppetlabs/packaging/compare/0.99.19...0.99.20
[0.99.19]: https://github.com/puppetlabs/packaging/compare/0.99.18...0.99.19
[0.99.18]: https://github.com/puppetlabs/packaging/compare/0.99.17...0.99.18
[0.99.17]: https://github.com/puppetlabs/packaging/compare/0.99.16...0.99.17
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
