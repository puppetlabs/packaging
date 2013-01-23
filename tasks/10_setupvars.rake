require 'yaml'
require 'erb'
require 'benchmark'
require File.expand_path('../build.rb', __FILE__)

# Where we get the data for our project depends on if a PARAMS_FILE environment
# variable is passed with the rake call. PARAMS_FILE should be a path to a yaml
# file containing all of the build parameters for a project, which are read
# into our BuildInstance object. If no build parameters file is specified, we
# assume input via the original methods of build_data.yaml and
# project_data.yaml. This also applies to the pl:fetch and pl:load_extras
# tasks, which are supplementary means of gathering data. These two are not
# used if a PARAMS_FILE is passed.
#
# Create our BuildInstance object, which will contain all the data about our
# proposed build
@build = Build::BuildInstance.new

if ENV['PARAMS_FILE'] && ENV['PARAMS_FILE'] != ''
  @build.set_params_from_file(ENV['PARAMS_FILE'])
else
  # Load information about the project from the default params files
  #
  @build.set_params_from_file('ext/project_data.yaml') if File.readable?('ext/project_data.yaml')
  @build.set_params_from_file('ext/build_defaults.yaml') if File.readable?('ext/build_defaults.yaml')

  # Allow environment variables to override the settings we just read in
  #
  @build.sign_tar        = boolean_value(ENV['SIGN_TAR']) if ENV['SIGN_TAR']
  @build.build_gem       = boolean_value(ENV['GEM'])      if ENV['GEM']
  @build.build_dmg       = boolean_value(ENV['DMG'])      if ENV['DMG']
  @build.build_ips       = boolean_value(ENV['IPS'])      if ENV['IPS']
  @build.build_doc       = boolean_value(ENV['DOC'])      if ENV['DOC']
  @build.build_pe        = boolean_value(ENV['PE_BUILD']) if ENV['PE_BUILD']
  @build.default_cow     = ENV['COW']                     if ENV['COW']
  @build.cows            = ENV['COW']                     if ENV['COW']
  @build.pbuild_conf     = ENV['PBUILDCONF']              if ENV['PBUILDCONF']
  @build.packager        = ENV['PACKAGER']                if ENV['PACKAGER']
  @build.default_mock    = ENV['MOCK']                    if ENV['MOCK']
  @build.final_mocks     = ENV['MOCK']                    if ENV['MOCK']
  @build.rc_mocks        = ENV['MOCK']                    if ENV['MOCK']
  @build.gpg_name        = ENV['GPG_NAME']                if ENV['GPG_NAME']
  @build.gpg_key         = ENV['GPG_KEY']                 if ENV['GPG_KEY']
  @build.certificate_pem = ENV['CERT_PEM']                if ENV['CERT_PEM']
  @build.privatekey_pem  = ENV['PRIVATE_PEM']             if ENV['PRIVATE_PEM']
  @build.yum_host        = ENV['YUM_HOST']                if ENV['YUM_HOST']
  @build.yum_repo_path   = ENV['YUM_REPO']                if ENV['YUM_REPO']
  @build.apt_host        = ENV['APT_HOST']                if ENV['APT_HOST']
  @build.apt_repo_path   = ENV['APT_REPO']                if ENV['APT_REPO']
end

@build.release           ||= get_release
@build.version           ||= get_dash_version
@build.gemversion        ||= get_dot_version
@build.ipsversion        ||= get_ips_version
@build.debversion        ||= get_debversion
@build.origversion       ||= get_origversion
@build.rpmversion        ||= get_rpmversion
@build.rpmrelease        ||= get_rpmrelease
@build.deb_env            = "COW='#{@build.cows}' RELEASE='#{@build.release}'"
@build.mockf_env          = "MOCK='#{@build.final_mocks}' RELEASE='#{@build.release}'"
@build.mockrc_env         = "MOCK='#{@build.rc_mocks}' RELEASE='#{@build.release}'"
@build.builder_data_file ||= 'builder_data.yaml'
@build.team              = ENV['TEAM'] || 'dev'
@keychain_loaded         ||= FALSE
@build_root              ||= Dir.pwd
