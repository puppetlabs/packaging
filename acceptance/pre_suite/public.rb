# This pre-suite file installs puppet-agent
# from the public build servers. These are
# listed below (append `.puppetlabs.com` to get
# the build server URL):
# - yum
# - apt
# - downloads

# Note that the PUPPET_VERSION is only required
# on apt build server URLs, as the install file
# name changes depending on which overall Puppet
# version is in use. This beaker method defaults
# to installing from the Puppet 3.x line, so the
# filename will not include the Puppet Collection:
# example:
# http://apt.puppetlabs.com/puppetlabs-release-wily.deb
# becomes
# http://apt.puppetlabs.com/puppetlabs-release-pc1-wily.deb
# at Puppet 4.x.
install_puppet_on(hosts, {
  :version              => ENV['PUPPET_VERSION']        || '4.8.0',
  :puppet_agent_version => ENV['PUPPET_AGENT_VERSION']  || '1.8.0'
})
