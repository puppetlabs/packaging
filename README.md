#Packaging

This is a repository for packaging automation for Puppet Labs software.
The goal is to abstract and automate packaging processes beyond individual
software projects to a level where this repo can be cloned inside any project
and used to build Debian and Redhat packages, as well as gems, apple packages
and tarballs. This repo is currently under heavy development and in a state
flux, and it should not be considered to have a formal API. However, every
effort is being made to ensure existing tasks/behavior are not broken as we
continue to iterate and improve upon it.

##Using the Packaging Repo

Several Puppet Labs projects are using the packaging repo. They are:

* puppet
* facter
* puppet-dashboard
* hiera
* puppetdb

as well as several closed-source projects, including
* live-management
* console-auth
* console

Generally speaking, the packaging repo should be compatible with ruby 1.8.7,
ruby 1.9.3 and rake 0.9.x. To pull the packaging tasks into your source repo,
do a `rake package:bootstrap`. This will clone this repo into the ext directory
of the project and make many packaging tasks available. The tasks are
generally grouped into two categories, `package:` namespaced tasks and `pl:`
namespaced tasks.

## `package:` tasks
`package:` namespaced tasks are general purpose tasks that are set up to use
the most minimal tool chain possible for creating packages. These tasks will
create rpms and debs, but any build dependencies will need to be satisifed by
the building host, and any dynamically generated dependencies may result in
packages that are only suitable for the OS/version of the build host. However,
for rolling one's own debs and rpms or for use in environments without many
OSes/versions, this may work just fine. To build an rpm using the packaging
repo, do a `rake package:rpm`. To build a deb, use `rake package:deb`.

## `pl:` tasks
`pl:` namespaced tasks rely on a slighly more complex toolchain for packaging
inside clean chroot environments for the various operating systems and
versions that Puppet Labs supports. On the rpm side, this is done with
[mock](http://fedoraproject.org/wiki/Projects/Mock) and for debs, we use
pdebuild and [cowbuilder](http://wiki.debian.org/cowbuilder). For the most
part, these tasks are keyed to puppetlabs infrastructure, and are used by the
Release Engineering team to create release packages. However, they can
certainly be modified to suit other environments, and much effort went into
making tasks as modular and reusable as possible. Several Puppet Labs-specific
tasks are only available if the file '~/.packaging' is present.
This file is created by the `pl:fetch` task, which curls two yaml files into 'team' and 'project' subdirectories.
from a [separate build data repository](https://github.com/puppetlabs/build-data),
which contains additional settings/data specific to Puppet Labs release
infrastructure. The goal in separating these data and tasks out is to refrain
from presenting by default yet more Puppet Labs-specific tasks that aren't
generally consumable by everyone. To build a deb from a local repository using
a `pl` task, ssh into a builder (e.g., one stood up using the modules detailed
below) and clone the source repo, e.g. puppet. Then, run `rake package:bootstrap`
and `rake pl:deb` to create a deb, and `rake pl:mock` to make an rpm (on a debian
or redhat host, respectively).

## `pe:` tasks
There is also a `pe:` namespace, for the building of Puppet Labs' Puppet
Enterprise packages that have been converted to using this repo. The `pe:`
tasks rely heavily on PL internal infrastructure, and are not generally useful
outside of this environment. To create packages, in the source repository run
`rake package:bootstrap`, followed by `rake pl:fetch`. These two commands
bootstrap the packaging environment and pull in the additional data needed for
PE building (see `pl:fetch` notes above).
Then, to make a debian package, run `rake pe:deb`, and to make an rpm, run
`rake pe:mock`. There are also `pe:deb_all` and `pe:mock_all` tasks, which build
packages against all shipped debian/redhat targets. The `pe:deb_all` task is not
generally necessary for developer use for building test packages; the `pe:deb`
task creates a package that will work against virtually all supported PE debian
versions. The same is generally true for PE internal rpms, but because of variances
in build macros for rpm, rpms should generally be built with `pe:mock_all`, and
then the desired version installed, or by building only for a specific target.
This is accomplished by passing MOCK=<mock> to the rake call, e.g. `rake pe:mock MOCK=<mock>`.
The available mocks are listed in `ext/build_defaults.yaml` after `final_mocks:`.
For PE, the mocks are formatted as `pupent-<peversion>-<distversion>-<arch>`, e.g.
`pupent-2.7-el5-i386`. To build for a specific target, set `MOCK=<mock>` to the mock
that matches the target. The `pe:deb` and `pe:mock` tasks work by using the `:remote` tasks for building on a
remote builder using the current committed state of the source repository. To forego
remote building and build on the local station (e.g., by ssh-ing into a remote
builder first), the tasks `pe:local_mock` and `pe:local_deb` build using the
local host.

## `:remote:` tasks
There are also sub-namespaces of `:pl` and `:pe` that are worth noting. First, the `:remote` namespace. Tasks under `:remote` perform builds remotely on internal builders from your local workstation. How they work:

1) Run `pl:fetch` to obtain extra data from the build-data repo. The data includes the hostnames of builders to use for packaging.

2) Create a git bundle of the local workspace and tar it up.

3) Create a build parameters file. The params file includes all the information about the build, including any values overridden with env vars, and the actual task to run, e.g. `rake pl:deb`.

4) scp the git bundle and build parameters file to a temporary directory on the builder hostname assigned to that particular package build type.

5) ssh into the builder, untar the git bundle, clone it, and run `rake package:bootstrap`.

6) ssh into the builder, cd into the cloned repo, and run `rake pl:build_from_params PARAMS_FILE=/path/to/previously/sent/file`.

7) Maintain the ssh connection until the build finishes, and rsync the packages from the builder to the local workstation.

## `:jenkins:` tasks
Jenkins tasks are similar to the `:remote:` tasks, but they do not require ssh access to the builders.
The jenkins tasks enable the packaging repo to kick off packaging builds on a
remote jenkins slave. They work in a similar way to the :remote tasks, but
with a few key differences. The jenkins tasks transmit information to a
jenkins coordinator, which handles the rest. The data passed are the
following:

1) $PROJECT\_BUNDLE - a tar.gz of a git-bundle from HEAD of the current
   project, which is cloned on the builder to set up a duplicate of this
    environment

2) $BUILD\_PROPERTIES - a build parameters file, containing all information about the build

3) $BUILD\_TYPE - the "type" of build, e.g. rpm, deb, gem, etc The jenkins url and job name
   are obtained via the team build-data file from
   [the build data repository](https://github.com/puppetlabs/build-data)

4) $PROJECT - the project we're building, e.g. facter, puppet. This is used later in
   determining the target for the build artifacts on the distribution server

5) $DOWNSTREAM\_JOB - The URL of a downstream job that jenkins should post to upon success. This is obtained via the DOWNSTREAM\_JOB environment variable.


On the Jenkins end, the job is a parameterized job that accepts five
parameters. Jenkins has the Parameterized Trigger Plugin, Workspace Cleanup
Plugin, and Node and Label Parameter Plugin in use for this job. The workspace
cleanup plugin cleans the workspace before each build. Two are file parameters,
two string parameters, and a Label parameter provided by the Node and Label
Parameter Plugin, as described above. When the pl:jenkins:\* task triggers a
build, it passes values for all of these parameters. The Label parameter is
associated with the build type. This way we can queue the job on a builder with
the appropriate capabilities just by assigning a builder the label "deb" or
"rpm," etc. The actual build itself is accomplished via a shell build task. The
contents of the task are:

```bash
#################

  SHA=$(echo $BUILD_PROPERTIES | cut -d '.' -f1)

  echo "Build type: $BUILD_TYPE"

 ### Create a local clone of the git-bundle that was passed
 # The bundle is a tarball, and since this is a project-agnostic
 # job, we don't actually know what's in it, just that it's a
 # git bundle.


  [ -f "PROJECT_BUNDLE" ] || exit 1
  mkdir project && tar -xzf PROJECT_BUNDLE -C project/

  cd project
    git clone --recursive $(ls) git_repo

    cd git_repo

      ### Clone the packaging repo
      rake package:bootstrap && rake pl:fetch

      ### Perform the build
      rake pl:load_extras pl:build_from_params PARAMS_FILE=$WORKSPACE/BUILD_PROPERTIES

      ### Send the results
      rake pl:jenkins:ship["artifacts"]

      ### If a downstream job was passed, trigger it now
      if [ -n "$DOWNSTREAM_JOB" ] ; then
        rake pl:jenkins:post["$DOWNSTREAM_JOB"]
      fi

#################
```

## Modules

A puppet module,
[puppetlabs-debbuilder](https://github.com/puppetlabs/puppetlabs-debbuilder),
has been created to stand up a debian build host compatible with the debian
side of this packaging repo. The rpm-side module,
[puppetlabs-rpmbuilder](https://github.com/puppetlabs/puppetlabs-rpmbuilder),
will set up an rpm builder.

## Clean up
To remove the packaging repo, remove the ext/packaging directory or run `rake
package:implode`.

##Setting up projects for the Packaging Repo

The packaging repo requires many project-side artifacts inside the ext
directory at the top level. [facter](https://github.com:puppetlabs/facter) and
[hiera](https://github.com:puppetlabs/hiera) are good examples.
It expects the following directory structure in the project

*   ext/{debian,redhat,osx}

each of which contains templated erb files using the instance variables
specified in the setupvars task. These include a debian changelog, a redhat
spec file, and an osx preflight and plist.

The top level Rakefile or a separate task file in the project should have the following added:

```ruby
Dir['ext/packaging/tasks/**/*.rake'].sort.each { |t| load t }

build_defs_file = 'ext/build_defaults.yaml'
if File.exist?(build_defs_file)
  begin
    require 'yaml'
    @build_defaults ||= YAML.load_file(build_defs_file)
  rescue Exception => e
    STDERR.puts "Unable to load yaml from #{build_defs_file}:"
    STDERR.puts e
  end
  @packaging_url  = @build_defaults['packaging_url']
  @packaging_repo = @build_defaults['packaging_repo']
  raise "Could not find packaging url in #{build_defs_file}" if @packaging_url.nil?
  raise "Could not find packaging repo in #{build_defs_file}" if @packaging_repo.nil?

  namespace :package do
    desc "Bootstrap packaging automation, e.g. clone into packaging repo"
    task :bootstrap do
      if File.exist?("ext/#{@packaging_repo}")
        puts "It looks like you already have ext/#{@packaging_repo}. If you don't like it, blow it away with package:implode."
      else
        cd 'ext' do
          %x{git clone #{@packaging_url}}
        end
      end
    end
    desc "Remove all cloned packaging automation"
    task :implode do
      rm_rf "ext/#{@packaging_repo}"
    end
  end
end
```

Also in ext should be two files, build_defaults.yaml and project_data.yaml.

This is the sample build_defaults.yaml file from Hiera:
```yaml
---
packaging_url: 'git@github.com:puppetlabs/packaging --branch=master'
packaging_repo: 'packaging'
default_cow: 'base-squeeze-i386.cow'
# Which debian distributions to build for. Noarch packages only need one arch of each cow.
cows: 'base-lucid-amd64.cow base-lucid-i386.cow base-natty-amd64.cow base-natty-i386.cow base-oneiric-amd64.cow base-oneiric-i386.cow base-precise-amd64.cow base-precise-i386.cow base-sid-amd64.cow base-sid-i386.cow base-squeeze-amd64.cow base-squeeze-i386.cow base-testing-amd64.cow base-testing-i386.cow base-wheezy-i386.cow'
# The pbuilder configuration file to use
pbuild_conf: '/etc/pbuilderrc'
# Who is packaging. Turns up in various packaging artifacts
packager: 'puppetlabs'
# Who is signing packages
gpg_name: 'info@puppetlabs.com'
# GPG key ID of the signer
gpg_key: '4BD6EC30'
# Whether to require tarball signing as a prerequisite of other package building
sign_tar: FALSE
# a space separated list of mock configs. These are the rpm distributions to package for. If a noarch package, only one arch of each is needed.
final_mocks: 'pl-el-5-i386 pl-el-5-x86_64 pl-el-6-i386 pl-el-6-x86_64 pl-fedora-16-i386 pl-fedora-16-x86_64 pl-fedora-17-i386 pl-fedora-17-x86_64'
# The host that contains the yum repository to ship to
yum_host: 'burji.puppetlabs.com'
# The remote path the repository on the yum\_host
yum_repo_path: '/some/repo/'
# The host that contains the apt repository to ship to
apt_host: 'burji.puppetlabs.com'
# The URL to use for the apt dependencies in cow building
apt_repo_url: 'http://apt.puppetlabs.com'
# The path on the remote apt host that debs should ship to
apt_repo_path: '/opt/repository/incoming'
# Whether to present the gem and apple tasks
build_gem: TRUE
build_dmg: TRUE
```
This is the sample project_data.yaml file:
```yaml
---
project: 'hiera'
author: 'Puppet Labs'
email: 'info@puppetlabs.com'
homepage: 'https://github.com/puppetlabs/hiera'
summary: 'Light weight hierarchical data store'
description: 'A pluggable data store for hierarcical data'
# file containing hard coded version information, if present
version_file: '/lib/hiera.rb'
# files and gem\_files are space separated lists
# files to be packaged into a tarball and released with deb/rpm
files: '[A-Z]* ext lib bin spec acceptance_tests'
# space separated list of files to *exclude* from the tarball
# note that each listing in files, above, is recursively copied into the tarball, so
# 'tar\_excludes' only needs to include any undesired subdirectories/files of the 'files'
# list to exclude
tar_excludes: 'ext/packaging lib/some_excluded_file'
# files to be packaged into a gem
gem_files: '{bin,lib}/**/* CHANGELOG COPYING README.md LICENSE'
# To exclude specific files from inclusion in a gem:
gem_excludes: 'lib/hiera/file_to_exclude.rb lib/hiera/directory_to_exclude'
# If gem name differs in some way from project name, e.g. only build gem for a client end
gem_name: hiera_the_gem
# If gem summary and/or description differs from general summary
gem_summary: 'A sub-set of the Hiera pluggable data store'
gem_description: 'A gem of the pluggable data store for hierarchical data'
gem_require_path: 'lib'
gem_test_files: 'spec/**/*'
gem_executables: 'hiera'
gem_default_executables: 'hiera'
# To add gem dependencies, indent.
# This is an example only, hiera doesn't really depend on hiera-puppet/json/facter
# For no specific version, leave version empty
gem_runtime_dependencies:
  hiera-puppet: '1.0.0rc'
  hiera-json:
gem_development_dependencies:
  facter: '>= 1.6.11'
# rdoc options as an array
gem_rdoc_options:
  - --line-numbers
  - --main
  - Hiera.README
```
For basic mac packaging, add an osx directory in ext containing the following files:
1. a preflight.erb template for any pre-flight actions, perhaps removing the old package if present.
2. a prototype.plist.erb that is templated into the pkginfo.plist file for the package. This is the one from puppet. Note that these variable names aren't mutable here, but there's no need to worry about their value assignment, it's done in the apple task:
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string><%= @title %></string>
  <key>CFBundleShortVersionString</key>
  <string><%= @version %></string>
  <key>IFMajorVersion</key>
  <integer><%= @package_major_version %></integer>
  <key>IFMinorVersion</key>
  <integer><%= @package_minor_version %></integer>
  <key>IFPkgBuildDate</key>
  <date><%= @build_date %></date>
  <key>IFPkgFlagAllowBackRev</key>
  <false/>
  <key>IFPkgFlagAuthorizationAction</key>
  <string>RootAuthorization</string>
  <key>IFPkgFlagDefaultLocation</key>
  <string>/</string>
  <key>IFPkgFlagFollowLinks</key>
  <true/>
  <key>IFPkgFlagInstallFat</key>
  <false/>
  <key>IFPkgFlagIsRequired</key>
  <false/>
  <key>IFPkgFlagOverwritePermissions</key>
  <false/>
  <key>IFPkgFlagRelocatable</key>
  <false/>
  <key>IFPkgFlagRestartAction</key>
  <string><%= @pm_restart %></string>
  <key>IFPkgFlagRootVolumeOnly</key>
  <true/>
  <key>IFPkgFlagUpdateInstalledLanguages</key>
  <false/>
</dict>
</plist>
```
A file_mapping.yaml file that specifies a set of files and a set of directories from the source to install, with destinations, ownership, and permissions. The directories are top level directories in the source to install. The files are files somewhere in the source to install. This is the one from puppet 3.x:
```yaml
---
directories:
# this will take the contents of lib, e.g. puppet/lib/\* and place them in /usr/lib/ruby/site\_ruby/1.8
  lib:
    path: 'usr/lib/ruby/site_ruby/1.8'
    owner: 'root'
    group: 'wheel'
    perms: '0644'
  bin:
    path: 'usr/bin'
    owner: 'root'
    group: 'wheel'
    perms: '0755'
  'man/man8':
    path: 'usr/share/man/man8'
    owner: 'root'
    group: 'wheel'
    perms: '0755'
files:
# this will take the file puppet/conf/auth.conf and place it in /private/etc/puppet/, creating the directory if not present
  'conf/auth.conf':
    path: 'private/etc/puppet'
    owner: 'root'
    group: 'wheel'
    perms: '0644'
  'man/man5/puppet.conf.5':
    path: 'usr/share/man/man5'
    owner: 'root'
    group: 'wheel'
    perms: '0644'
  '[A-Z]*':
    path: 'usr/share/doc/puppet'
    owner: 'root'
    group: 'wheel'
    perms: '0644'
```
