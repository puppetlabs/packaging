require 'yaml'
require 'erb'
require 'benchmark'
load File.expand_path('../build.rake', __FILE__)

##
# Where we get the data for our project depends on if a PARAMS_FILE environment
# variable is passed with the rake call. PARAMS_FILE should be a path to a yaml
# file containing all of the build parameters for a project, which are read
# into our BuildInstance object. If no build parameters file is specified, we
# assume input via the original methods of build_data.yaml and
# project_data.yaml. This also applies to the pl:fetch and pl:load_extras
# tasks, which are supplementary means of gathering data. These two are not
# used if a PARAMS_FILE is passed.

##
# Create our BuildInstance object, which will contain all the data about our
# proposed build
#
@build = Build::BuildInstance.new

if ENV['PARAMS_FILE'] && ENV['PARAMS_FILE'] != ''
  @build.set_params_from_file(ENV['PARAMS_FILE'])
else
  # Load information about the project from the default params files
  #
  @build.set_params_from_file('ext/project_data.yaml') if File.readable?('ext/project_data.yaml')
  @build.set_params_from_file('ext/build_defaults.yaml') if File.readable?('ext/build_defaults.yaml')
end

# Allow environment variables to override the settings we just read in. These
# variables are called out specifically because they are likely to require
# overriding in at least some cases.
#
@build.sign_tar            = boolean_value(ENV['SIGN_TAR'])          if ENV['SIGN_TAR']
@build.build_gem           = boolean_value(ENV['GEM'])               if ENV['GEM']
@build.build_dmg           = boolean_value(ENV['DMG'])               if ENV['DMG']
@build.build_ips           = boolean_value(ENV['IPS'])               if ENV['IPS']
@build.build_doc           = boolean_value(ENV['DOC'])               if ENV['DOC']
@build.build_pe            = boolean_value(ENV['PE_BUILD'])          if ENV['PE_BUILD']
@build.debug               = boolean_value(ENV['DEBUG'])             if ENV['DEBUG']
@build.update_version_file = ENV['NEW_STYLE_PACKAGE']                if ENV['NEW_STYLE_PACKAGE']
@build.default_cow         = ENV['COW']                              if ENV['COW']
@build.cows                = ENV['COW']                              if ENV['COW']
@build.pbuild_conf         = ENV['PBUILDCONF']                       if ENV['PBUILDCONF']
@build.packager            = ENV['PACKAGER']                         if ENV['PACKAGER']
@build.default_mock        = ENV['MOCK']                             if ENV['MOCK']
@build.final_mocks         = ENV['MOCK']                             if ENV['MOCK']
@build.rc_mocks            = ENV['MOCK']                             if ENV['MOCK']
@build.gpg_name            = ENV['GPG_NAME']                         if ENV['GPG_NAME']
@build.gpg_key             = ENV['GPG_KEY']                          if ENV['GPG_KEY']
@build.certificate_pem     = ENV['CERT_PEM']                         if ENV['CERT_PEM']
@build.privatekey_pem      = ENV['PRIVATE_PEM']                      if ENV['PRIVATE_PEM']
@build.yum_host            = ENV['YUM_HOST']                         if ENV['YUM_HOST']
@build.yum_repo_path       = ENV['YUM_REPO']                         if ENV['YUM_REPO']
@build.apt_host            = ENV['APT_HOST']                         if ENV['APT_HOST']
@build.apt_repo_path       = ENV['APT_REPO']                         if ENV['APT_REPO']
@build.pe_version          = ENV['PE_VER']                           if ENV['PE_VER']
@build.notify              = ENV['NOTIFY']                           if ENV['NOTIFY']

##
# These parameters are either generated dynamically by the project, or aren't
# sufficiently generic/multi-purpose enough to justify being in
# build_defaults.yaml or project_data.yaml.
#
@build.release           ||= get_release
@build.version           ||= get_dash_version
@build.gemversion        ||= get_dot_version
@build.ipsversion        ||= get_ips_version
@build.debversion        ||= get_debversion
@build.origversion       ||= get_origversion
@build.rpmversion        ||= get_rpmversion
@build.rpmrelease        ||= get_rpmrelease
@build.builder_data_file ||= 'builder_data.yaml'
@build.team              = ENV['TEAM'] || 'dev'
@build.random_mockroot   = ENV['RANDOM_MOCKROOT'] ? boolean_value(ENV['RANDOM_MOCKROOT']) : true
@keychain_loaded         ||= FALSE
@build_root              ||= Dir.pwd
@build.build_date        ||= timestamp('-')
##
# For backwards compatibilty, we set build:@name to build:@project. @name was
# renamed to @project in an effort to align the variable names with what has
# been supported for parameter names in the params files.
@build.name = @build.project
# We also set @tar_host to @yum_host if @tar_host is not set. This is in
# another effort to fix dumb mistakes. Early on, we just assumed tarballs would
# go to @yum_host (why? probably just laziness) but this is not ideal and does
# not make any sense when looking at the code. Now there's a @tar_host
# variable, but for backwards compatibility, we'll default back to @yum_host if
# @tar_host isn't set.
@build.tar_host ||= @build.yum_host

# Though undocumented, we had specified gem_devel_dependencies as an allowed
# parameter for @build, and it was supposed to correspond with
# gem_development_dependencies in a gem spec. It was dumb to call it 'devel'
# instead of 'development', which would have been a cleaner mapping. Here, we
# deprecate this.
if @build.gem_devel_dependencies
  @build.gem_development_dependencies = @build.gem_devel_dependencies
  warn "
  DEPRECATED, 9-Nov-2013: 'gem_devel_dependencies' has been replaced with
  'gem_development_dependencies.' Please update this field in your
  project_data.yaml
  "
end

if @build.debug
  @build.print_params
end

##
# MM 1-22-2013
# We have long made all of the variables available to erb templates in the
# various projects. The problem is now that we've switched to encapsulating all
# of this inside a build object, that information is no longer available. This
# section is for backwards compatibility only. It sets an instance variable
# for all of the parameters inside the build object. This is repeated in
# 20_setupextrasvars.rake. Note: The intention is to eventually abolish this
# behavior. We want to access information from the build object, not in what
# are essentially globally available rake variables.
#
@build.params.each do |param, value|
  self.instance_variable_set("@#{param}", value)
end

##
# Issue a deprecation warning if the packaging repo wasn't loaded by the loader
unless @using_loader
  warn "
  DEPRECATED: The packaging repo tasks are now loaded by 'packaging.rake'.
  Please update your Rakefile or loading task to load
  'ext/packaging/packaging.rake' instead of 'ext/packaging/tasks/*' (25-Jun-2013).
  "
end

