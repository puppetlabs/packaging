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
* razor

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
inside clean chroot environments for the various operating systems and versions
that Puppet Labs supports. On the rpm side, this is done with
[mock](http://fedoraproject.org/wiki/Projects/Mock) and for debs, we use
pdebuild and [cowbuilder](http://wiki.debian.org/cowbuilder). For the most
part, these tasks are keyed to puppetlabs infrastructure, and are used by the
Release Engineering team to create release packages. However, they can
certainly be modified to suit other environments, and much effort went into
making tasks as modular and reusable as possible. Several Puppet Labs-specific
tasks are only available if the file '~/.packaging' is present.  This file is
created by the `pl:fetch` task, which curls two yaml files into 'team' and
'project' subdirectories from a [separate build data
repository](https://github.com/puppetlabs/build-data), which contains
additional settings/data specific to Puppet Labs release infrastructure. By
default, the team data file is pulled from the 'dev' branch of the repo, and
the project data file is pulled from a branch named after the project (e.g. for
puppet, there is a branch named puppet with a build data file). The goal in
separating these data and tasks out is to refrain from presenting by
default yet more Puppet Labs-specific tasks that aren't generally consumable by
everyone. To build a deb from a local repository using a `pl` task, ssh into a
builder (e.g., one stood up using the modules detailed below) and clone the
source repo, e.g. puppet. Then, run `rake package:bootstrap` and `rake pl:deb`
to create a deb, and `rake pl:mock` to make an rpm (on a debian or redhat host,
respectively).

## `pe:` tasks
There is also a `pe:` namespace, for the building of Puppet
Labs' Puppet Enterprise packages that have been converted to using this repo.
The `pe:` tasks rely heavily on PL internal infrastructure, and are not
generally useful outside of this environment. To create packages, in the source
repository run `rake package:bootstrap`, followed by `rake pl:fetch`. These two
commands bootstrap the packaging environment and pull in the additional data
needed for PE building (see `pl:fetch` notes above).  Then, to make a debian
package, run `rake pe:deb`, and to make an rpm, run `rake pe:mock`. There are
also `pe:deb_all` and `pe:mock_all` tasks, which build packages against all
shipped debian/redhat targets. The `pe:deb_all` task is not generally necessary
for developer use for building test packages; the `pe:deb` task creates a
  package that will work against virtually all supported PE debian versions.
  The same is generally true for PE internal rpms, but because of variances in
  build macros for rpm, rpms should generally be built with `pe:mock_all`, and
  then the desired version installed, or by building only for a specific
  target.  This is accomplished by passing MOCK=<mock> to the rake call, e.g.
  `rake pe:mock MOCK=<mock>`.  The available mocks are listed in
  `ext/build_defaults.yaml` after `final_mocks:`.  For PE, the mocks are
  formatted as `pupent-<peversion>-<distversion>-<arch>`, e.g.
  `pupent-2.7-el5-i386`. To build for a specific target, set `MOCK=<mock>` to
  the mock that matches the target. The `pe:deb` and `pe:mock` tasks work by
  using the `:remote` tasks for building on a remote builder using the current
  committed state of the source repository. To forego remote building and build
  on the local station (e.g., by ssh-ing into a remote builder first), the
  tasks `pe:local_mock` and `pe:local_deb` build using the local host.

## `:remote:` tasks
There are also sub-namespaces of `:pl` and `:pe` that are
worth noting. First, the `:remote` namespace. Tasks under `:remote` perform
builds remotely on internal builders from your local workstation. How they
work:

1) Run `pl:fetch` to obtain extra data from the build-data repo. The data
includes the hostnames of builders to use for packaging.

2) Create a git bundle of the local workspace and tar it up.

3) Create a build parameters file. The params file includes all the information
about the build, including any values overridden with env vars, and the actual
task to run, e.g. `rake pl:deb`.

4) scp the git bundle and build parameters file to a temporary directory on the
builder hostname assigned to that particular package build type.

5) ssh into the builder, untar the git bundle, clone it, and run `rake
package:bootstrap`.

6) ssh into the builder, cd into the cloned repo, and run `rake
pl:build_from_params PARAMS_FILE=/path/to/previously/sent/file`.

7) Maintain the ssh connection until the build finishes, and rsync the packages
from the builder to the local workstation.

Note that these tasks require ssh access to the builder hosts that are
specified in the build-data file, and appropriate membership in the build
groups, e.g. to use mock on the builder, membership in the mock group. This is
a major hurdle, and is resolved with the `jenkins` tasks below.

## `:jenkins:` tasks
Jenkins tasks are similar to the `:remote:` tasks, but they do not require ssh
access to the builders. They do require being on the local network - the
jenkins instance that performs package builds is an internal server only,
accessible when connected via VPN or on-site.  The jenkins tasks enable the
packaging repo to kick off packaging builds on a remote jenkins slave. They
work in a similar way to the :remote tasks, but with a few key differences. The
jenkins tasks transmit information to a jenkins coordinator, which handles the
rest. The data passed are the following:

1) $PROJECT\_BUNDLE - a tar.gz of a git-bundle from HEAD of the current
project, which is cloned on the builder to set up a duplicate of this
environment

2) $BUILD\_PROPERTIES - a build parameters file, containing all information
about the build

3) $BUILD\_TYPE - the "type" of build, e.g. rpm, deb, gem, etc The jenkins url
and job name are obtained via the team build-data file from [the build data
repository](https://github.com/puppetlabs/build-data)

4) $PROJECT - the project we're building, e.g. facter, puppet. This is used
later in determining the target for the build artifacts on the distribution
server

5) $DOWNSTREAM\_JOB - The URL of a downstream job that jenkins should post to
upon success. This is obtained via the DOWNSTREAM\_JOB environment variable.


On the Jenkins end, the job is a parameterized job that accepts five
parameters. Jenkins has the Parameterized Trigger Plugin, Workspace Cleanup
Plugin, and Node and Label Parameter Plugin in use for this job. The workspace
cleanup plugin cleans the workspace before each build. Two are file parameters,
two string parameters, and a Label parameter provided by the Node and Label
Parameter Plugin, as described above. When the pl:jenkins:\* task triggers a
build, it passes values for all of these parameters. The Label parameter is
associated with the build type. This way we can queue the job on a builder with
the appropriate capabilities just by assigning a builder the label "deb" or
"rpm," etc. The job allows parallel execution of jobs - in this way, we can
queue many package jobs on the jenkins instance, which will farm them out to
builders that are slaves of that jenkins instance. This also allows us to scale
building capacity simply by adding builders as slaves to the jenkins instance.
The actual build itself is accomplished via a shell build task. The contents of
the task are:

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

## Using Managed jenkins:uber\_build tasks

## [ Experimental ] ##

By passing MANAGED=true on the command line to either pe:jenkins:uber_build or
pl:jenkins:uber_build, you can invoke the "Managed Build" feature of these
tasks. The managed build feature redefines tasks to interact with the [Build
Manager](https://github.com/puppetlabs/build-manager). The Build Manager
ensures that the job specified in the DOWNSTREAM\_JOB environment variable is
only called once all individual builds have
completed successfully in a jenkins:uber_build.

When using the managed task feature, you must also set a STATUS\_JOB
environment variable. The build manager will call this job with the following
parameters:

1) $SHA - the git sha (or tag) of the package that was built

2) $status - the build status string. This will be "All Builds
Succeeded" for a successful build, or a string containing information
on failed jobs.

The recommended code for the status job is below:

```bash
#!/bin/bash -e

echo "${SHA} completed!"
echo "${status}"
[[ $status == "All Builds Succeeded" ]]
```
This will enable a status indicator on the health of your packaging jobs, in
addition to merely not kicking off the downstream job.

## Task Explanations
For a listing of all available tasks and their functions, see the [Task
Dictionary](https://github.com/MosesMendoza/packaging/tree/more_documentation#task-dictionary)
at the end of this README.

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
# Whether to execute the rdoc rake tasks prior to composing the tarball
build_doc: FALSE
# Whether to present the Solaris 11 IPS packaging tasks
# This requires suitable IPS packaging artifacts in the project in ext/ips
build_ips: FALSE
# Whether this project is a PE project or not
build_pe: FALSE
# An optional task to execute pre-tarball composition. See the tasks in
# the 'pretasks' directory
pre_tar_task: 'package:vendor_gems'
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
A file_mapping.yaml file that specifies a set of files and a set of directories
from the source to install, with destinations, ownership, and permissions. The
directories are top level directories in the source to install. The files are
files somewhere in the source to install. This is the one from puppet 3.x:
```yaml
---
directories:
# this will take the contents of lib, e.g. puppet/lib/\* and place them in
# /usr/lib/ruby/site\_ruby/1.8
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
# this will take the file puppet/conf/auth.conf and place it in
# /private/etc/puppet/, creating the directory if not present
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

## Task Dictionary

* **package:apple**

    Use `PackageMaker` to create a pkg package inside a dmg. Requires 'sudo'
    privileges. `build_dmg: TRUE` must be set in `ext/build_defaults.yaml`.
    Packages are staged in ./pkg/apple. See the Mac packaging section of
    [Setting up projects for the Packaging
    Repo](https://github.com/MosesMendoza/packaging/tree/more_documentation#setting-up-projects-for-the-packaging-repo).

* **package:bootstrap**

    Clone the packaging repo into this project. This task isn't actually in the
    packaging repo itself, but resides in the project. See [Setting up projects
    for the Packaging
      Repo](https://github.com/puppetlabs/packaging#setting-up-projects-for-the-packaging-repo).

* **package:deb**

    Use `debbuild` to create a deb package and associated debian package
    artifacts from the repository. Requires all build dependencies be satisfied
    locally. Packages are staged in ./pkg/deb.

* **package:gem**
    Use the `rubygems/package_task` library to create a rubygem from the
    repository. Requires `build_gem: TRUE` and gem-related parameters be set in
    `ext/build_defaults.yaml` and `ext/project\_data.yaml`. The gem is staged
    in `./pkg`.

* **package:implode**

    Remove the packaging repo entirely from the project. This task isn't
    actually in the packaging repo itself, but resides in the project. See
    [Setting up projects for the Packaging
    Repo](https://github.com/puppetlabs/packaging#setting-up-projects-for-the-packaging-repo).

* **package:ips**

    Use Solaris 11 pkg* tools to create a IPS package from the project.
    Packages are staged in `./pkg/ips/pkgs`. Requires all `pkg`, `pkgdepend`,
    `pkgsend`, `pkglint`, and `pkgmogrify`. Currently only puppet, facter, and
    hiera have this capability.

* **package:rpm**

    Use `rpmbuild` to create an rpm of the project. This will also make a
    source rpm. Requires all build dependencies by satisfied locally. Packages
    are staged in `./pkg/rpm`.

* **package:srpm**

    Use `rpmbuild` to create a source rpm of the project. Source rpm is staged
    in `./pkg/srpm`.

* **package:tar**

    Create a source tarball of the project. The tarball is staged in `./pkg`.

* **package:update**

    Update the clone of the packaging repo by pulling from origin.

* **pl:build_from_params**

    Invoke a build from a build parameters yaml file. The parameters file
    should be created with `rake pl:write_build_params`. The settings in the
    build parameters file will override all values contained in
    `./ext/build_defaults.yaml` and `./ext/project_data.yaml`.

* **pl:deb**

    Use pdebuild with cowbuilder to create a debian package and associated
    source artifacts from the default "cow", currently Debian Squeeze i386.
    Requires that pbuilder/cowbuilder be installed and set up with a Debian
    Squeeze cow. See the
    [puppetlabs-debbuilder](https://github.com/puppetlabs/puppetlabs-debbuilder)
    module for an easy way to set up a host for building with cows. The deb and
    source artifacts are staged in `./pkg/deb/squeeze`.

* **pl:deb_all***

    The same as `rake pl:deb`, but a package is built for every cow listed in
    `ext/build_defaults.yaml` on the line `cows:<cows>`. The packages and
    associated source artifacts are staged in `./pkg/deb/$distribution`, where
    $distribution is the Debian/Ubuntu codename of the cow that was used to
    build the package, e.g. "wheezy" or "precise."

* **pl:ips**

    Invoke package:ips, but do so after pl:fetch and pl:load_extras, which load
    signing/certificate information. The resulting packages are signed. IPS
    packages are staged in `./pkg/ips/pkgs`

* **pl:jenkins:deb**

    Perform `pl:deb` by posting a jenkins build, as described above. Once the
    build is complete, run `pl:jenkins:retrieve` to retrieve the built
    packages.

* **pl:jenkins:deb_all**

    Perform what is a effectively a `pl:deb_all` but in a different fashion.
    `pl:deb_all` performs debian cow builds in serial with every cow listed in
    ext/build_defaults.yaml. `pl:jenkins:deb_all` splits the cows listed, and
    posts a separate `pl:jenkins:deb` job for every cow listed to the jenkins
    server, allowing jenkins to parallelize the building of packages for every
    cow. Execute `pl:jenkins:retrieve` to retrieve all packages.

* **pl:jenkins:deb_repo_configs**

    On the distribution server generate a listing of all debian repositories
    that exist for the current SHA/ref of HEAD of the project repository. Then
    generate debian apt client configuration files for every existing
    repository. The distribution server is a web server, so the client
    configurations can be placed on a debian client in /etc/apt/sources.list.d/
    and the client will be able to install the built packages via apt. Requires
    SSH access to the distribution server.

* **pl:jenkins:deb_repos**

    On the distribution server, generate debian apt repositories for every
    distribution containing any packages that are stored that match the current
    SHA/ref of HEAD of the project repository. Requires SSH access to the
    distribution server.

* **pl:jenkins:dmg**

    Perform `package:apple` by posting a jenkins build. Run
    `pl:jenkins:retrieve` to retrieve the built packages.

* **pl:jenkins:gem**

    Perform `package:gem` by posting a jenkins build. Run `pl:jenkins:retrieve`
    to retrieve the built packages.

* **pl:jenkins:mock**

    Perform `pl:mock` by posting a jenkins build. Run `pl:jenkins:retrieve` to
    retrieve the built packages.

* **pl:jenkins:mock_all**

    Perform what is effectively a `pl:mock_all` but in a different fashion.
    `pl:mock_all` performs mock builds in serial with every mock listed in
    ext/build_defaults.yaml. `pl:jenkins:mock_all` splits the mocks listed, and
    posts a separate `pl:jenkins:mock` job for every mock to the jenkins
    server, allowing jenkins to parallelize the building of packages for every
    mock configuration. The mock build root is randomized by the packaging
    repo, avoiding conflicts with existing builds of the same mock
    configuration. To retrieve built packages, call `pl:jenkins:retrieve`.

* **pl:jenkins:post[uri]**

    Post to the jenkins server as specified in the team build_extras.yaml file,
    with the job uri specified.

* **pl:jenkins:retrieve[target]**

    Retrieve packages stored on the distribution server that have been built
    from the current SHA/ref of HEAD of the project repository. Optionally pass
    [target] to override the default, which is to retrieve the contents of the
    "artifacts" subdirectory. Other targets are "repos" and "shipped".

* **pl:jenkins:rpm_repo_configs**

    On the distribution server generate a listing of all yum rpm package
    repositories that exist for the current SHA/ref of HEAD of the project
    repository. Then generate yum client configuration files for every existing
    repository. The distribution server is a web server, so the client
    configurations can be placed on a redhat client in /etc/yum.repos.d/ and
    the client will be able to install the packages via yum install. Requires
    SSH access to the distribution server.

* **pl:jenkins:rpm_repos**

    On the distribution server, generate yum rpm repositories for every
    distribution containing any packages that are stored that match the current
    SHA/ref of HEAD of the project repository. Requires SSH access to the
    distribution server. The yum repos are created in a "repos" subdirectory of
    the standard builds location, e.g.
    /opt/jenkins-builds/$project/${SHA|ref}/repos, using everything currently
    in the "artifacts" subdirectory of the same location.

* **pl:jenkins:ship[target]**

    Take the packages staged in pkg/ and ship them to locations partially
    specified by data in the project build_extras.yaml file. The current
    paradigm is to ship the files to a subdirectory of /opt/jenkins-builds on
    the distribution server. The subdirectory is constructed with the project
    and SHA or ref of HEAD of the project repository. That is, if project HEAD
    is currently at the tag "1.2.3", then the directory that packages will be
    shipped to is /opt/jenkins-builds/$project/1.2.3/. If HEAD is a git SHA,
    then "1.2.3" will instead be that SHA. By default, all artifacts in pkg/
    will be shipped to a "artifacts" subdirectory of the standard target. E.g.
    /opt/jenkins-builds/$project/1.2.3/artifacts. When a final shipping occurs,
    e.g. when shipping signed artifacts into production, a second subdirectory
    is created - "shipped" - and all artifacts that are shipped to production
    are also shipped here. This allows a historical archive of all shipped
    artifacts.

* **pl:jenkins:sign_all**

    Take all packages staged in pkg/ and sign them via the various signing
    tasks. All signing occurs on the distribution server:
    * create a git-bundle of the project and rsync it to the distribution
    * server ssh to the distribution server and clone the git-bundle, and clone
    * the packaging repository rsync the contents of the local pkg/ directory
    * into the pkg/ directory of the remote git project ssh to the distribution
    * server and execute the following rake tasks:
      - pl:sign_tar
      - pl:sign_rpms
      - pl:sign_deb_changes
    * rsync the remote pkg/ directory contents to the local pkg/ directory

* **pl:jenkins:tar**

    Perform `package:tar` by posting a jenkins build. Run `pl:jenkins:retrieve` to
    retrieve the built packages.

* **pl:jenkins:uber_build**

    An aggregate of build tasks. These include `jenkins:deb_all`,
    `pl:jenkins:mock_all`, `pl:jenkins:tar`, `pl:jenkins:dmg`, and `pl:jenkins:gem`. Each
    task is a separate job that is posted to the jenkins build server,
    separated by a 5 second sleep.

* **pl:jenkins:uber_ship**

    An aggregate of retrieval, signing, and shipping tasks. Execute
    `pl:jenkins:retrieve` to retrieve any packages on the distribution server
    that were built from the SHA/ref of HEAD. Then `pl:jenkins:sign_all` to
    sign all packages. Finally, `pl:uber_ship`, `pl:remote:freight`, and
    `pl:remote:update_yum_repo`. `pl:jenkins:uber_build` combined with
    `pl:jenkins:uber_ship` performs the entire build and release process for a
    project.

* **pl:mock**

    Use `mock` to build an rpm package using the default mock distribution,
    Redhat Linux 5, i386. Requires that the `mock` package be installed. See
    the
    [puppetlabs-rpmbuilder](https://github.com/puppetlabs/puppetlabs-rpmbuilder)
    module for an easy way to set up a host for building with mock. Resulting
    rpm is staged in `./pkg/el/rpm/5/(products | devel)/(i386 | SRPMS)`. The
    placement into the "products" or "devel" subdirectories is determined by
    the name of the package. If the package has a Release Candidate version, it
    is placed in "devel". Otherwise it is placed in "products". A Release
    Candidate is determined by parsing the `git describe` string, and searching
    for `rc` after the version numbers.

* **pl:mock_all**

    The same as `rake pl:mock`, but a package is built for every mock listed in
    `ext/build_defaults.yaml` on the line `mocks:<mocks>`. Packages are staged
    in `./pkg/(el | fedora)/$version/(products | devel)/(i386 | x86_64 |
    SRPMS)`. The subdirectories are dependent on the mock that is used. The
    task assumes that the mock configurations are the standard Puppet Labs mock
    configurations that are generated by the
    [puppetlabs-rpmbuilder](https://github.com/puppetlabs/puppetlabs-rpmbuilder)
    module.

* **pl:print_build_params**

    Print all build parameters to STDOUT as they would be used in a package
    build. This prints data that is loaded from `ext/build_defaults.yaml` and
    `ext/project_data.yaml`, as well as whatever is overridden with environment
    variables. Useful for debugging problems with parameter values.

* **pl:release_deb**

    A composite task of `package:tar`, `pl:deb_all`, `pl:sign_deb_changes`, and
    `pl:ship_debs`

* **pl:release_dmg**

    A composite task of `package:apple`, and `pl:ship_dmg`

* **pl:release_gem**

    A composite task of `package:gem`, and `pl:ship_gem`

* **pl:release_ips**

    A composite task of `pl:ips`, and `pl:ship_ips`

* **pl:release_rpm**

    A composite task of `pl:mock_all`, `pl:sign_rpms`, `pl:ship_rpms`, and
    `pl:remote:update_yum_repo`

* **pl:release_tar**

    A composes task of `package:tar`, `pl:sign_tar`, and `pl:ship_tar`

* **pl:remote:deb**

    As described above, this is a remote task, which means that the task is
    performed remotely on the debian build host as specified in team
    build_data.yaml retrieved from github.com/puppetlabs/build-data. This task
    performs a `pl:deb` remotely on the builder

* **pl:remote:deb_all**

    Perform `pl:deb_all` on the remote debian build host as specified in the
    team build_data.yaml file

* **pl:remote:dmg**


    Perform `package:apple` on the remote Mac build host as specified in the
    team build_data.yaml file

* **pl:remote:freight**

    Performs an ssh call to the package server that calls a server-side rake
    task. The rake task takes the debian packages that have (presumably) been
    shipped via `pl:ship_debs` and invokes
    [freight](https://github.com/rcrowley/freight) with them, which places them
    in the apt repository.

* **pl:remote:ips**

    Perform `pl:ips` on the remote IPS build host as specified in the team
    build_data.yaml file

* **pl:remote:mock**

    Perform `pl:mock` on the remote RPM build host as specified in the team
    build_data.yaml file

* **pl:remote:mock_all**

    Perform `pl:mock_all` on the remote RPM build host as specified in the team
    build_data.yaml file

* **pl:remote:release_deb**

    Perform `pl:release_deb` on the remote debian build host. The caveat is
    that while performing a `pl:release:deb` locally will prompt you to confirm
    shipping the resulting debian packages, `pl:remote:release_deb` overrides
    this and just retrieves the packages, to be staged locally under pkg/deb.

* **pl:remote:release_rpm**

    Perform `pl:release_rpm` on the remote RPM build host. The same caveat
    applies as for `pl:remote:release_deb` - Packages aren't shipped into
    production, but rather retrieved from the remote builder and staged locally
    under pkg/el and pkg/fedora.

* **pl:remote:update_yum_repo**

    As with `pl:remote:freight`, this task performs an ssh call to the yum RPM
    package server, and invokes an existing server-side rake task. The task
    iterates through the `el` and `fedora` directories of the yum repository
    and re-creates package server metadata for rpms in the subdirectories.

* **pl:ship_debs**

    Rsync pkg/deb/* to the "incoming" directory on the debian apt package
    repository server. Note: this task does not place the packages into
    production - it is more accurate to consider the packages "staged" on the
    repository server rather than actually shipped. The `pl:remote:freight`
    task takes the packages in the "incoming" directory and actually places
    them in the apt server.

* **pl:ship_gem**

    Takes the built gem in pkg/ and pushes it to rubygems.com. This task assumes
    you have the appropriate rubygems.com access and config to push the gem.

* **pl:ship_ips**

    Takes the IPS packages in pkg/ips/pkgs/ and rsyncs them to a holding
    directory on a package download server. This is not a true IPS server yet,
    but just a basic file server. Eventually the goal is to have a true IPS
    package repository running.

* **pl:ship_rpms**

    Rsyncs the contents of pkg/el and pkg/fedora into the yum repository
    server. While these packages are available immediately for download by
    browsing the yum server directories directly, the yum repodata metadata has
    not been updated, and thus the packages are not available to yum clients.
    The `pl:remote:update_yum_repo` task updates the metadata, after which the
    packages will be available to yum clients.

* **pl:sign_rpms**

    Sign the rpms staged locally under pkg/ with the gpg key user ID (e.g.
    email) specified in ext/build_defaults.yaml as `gpg_name`. This value can
    be overridden by passing GPG_NAME as an environment variable to the rake
    task.

* **pl:sign_tar**

    Use gpg to create a detached signature of the tarball. By default this uses
    the gpg_key value specified in ext/build_defaults.yaml in the project. This
    can be overridden by passing GPG_KEY as an environment variable to the rake
    task.

* **pl:tag**

    Create a signed, annotated git tag of the current repository. Requires TAG
    be passed as an environment variable to the rake task, which is the value
    that will be used as both the tag message and the name of the tag. The gpg
    key that is used for signing is assumed from gpg_key in
    ext/build_defaults.yaml. This can be overridden by passing GPG_KEY as an
    environment variable to the rake task.

* **pl:uber_release**

    A composite task that performs the following tasks:  
    `package:gem` (if build_gem is "true" in build_defaults.yaml)  
    `pl:remote:release_deb`  
    `pl:remote:release_rpm`  
    `pl:remote:dmg` (if build_dmg is "true" in build_defaults.yaml)  
    `package:tar`  
    `pl:sign_tar`  
    `pl:uber_ship`  
    `pl:remote:freight`  
    `pl:remote:update_yum_repo`  
    This is essentially a complete build from start to finish. Gem and tarball
    are generated locally, and other packages (deb, rpm, dmg) are all created
    remotely. Assumes ssh access and appropriate build tool access on all
    respective build hosts.

* **pl:uber_ship**

    A composite task that performs the following tasks:  
    `pl:ship_gem`  
    `pl:ship_rpms`  
    `pl:ship_debs`  
    `pl:ship_dmgs`  
    `pl:ship_tar`  
    `pl:jenkins:ship`  
    This is essentially a "ship all the things" task, but it is important to
    note that it does not update either yum or apt repo metadata on these
    respective servers - this has to be done via `pl:remote:update_yum_repo`
    and `pl:remote:freight`.

* **pl:update_ips_repo**

    Take the packages in pkg/ips/pkg and rsync them to the IPS repository
    server specified in the build_extras.yaml file. Via ssh commands, call
    pkgrecv, pkgrepo, svcadm on the IPS repository server. Via ssh, restart the
    IPS repository service.

* **pl:write_build_params**

    Generate a yaml file with all the build properties that have been loaded
    from build_defaults.yaml, project_data.yaml, (optionally)
    build_extras.yaml(s) via `pl:fetch`, and any environment variables. This
    file can be used by the packaging repo as a single source of truth for
    build data via `pl:build_from_params`. By default it is written to a
    temporary location and its location is printed to STDOUT. To override the
    destination, pass OUTPUT_DIR as a environment variable to the task. By
    default, the name of the file will be either the git tag, if HEAD of the
    project repository is a tag, or the git sha of HEAD.

