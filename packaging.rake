# Load packaging repo tasks

# These are ordered

PACKAGING_PATH = File.join(File.dirname(__FILE__), 'tasks')

@using_loader = true

[ '00_utils.rake',
  '10_setupvars.rake',
  '20_setupextravars.rake',
  '30_metrics.rake',
  'apple.rake',
  'build.rake',
  'clean.rake',
  'deb.rake',
  'deb_repos.rake',
  'doc.rake',
  'fetch.rake',
  'gem.rake',
  'ips.rake',
  'jenkins.rake',
  'jenkins_dynamic.rake',
  'mock.rake',
  'pe_deb.rake',
  'pe_remote.rake',
  'pe_rpm.rake',
  'pe_ship.rake',
  'pe_sign.rake',
  'pe_sles.rake',
  'pe_tar.rake',
  'pre_tasks.rake',
  'release.rake',
  'remote_build.rake',
  'retrieve.rake',
  'rpm.rake',
  'rpm_repos.rake',
  'ship.rake',
  'sign.rake',
  'tag.rake',
  'tar.rake',
  'template.rake',
  'update.rake',
  'vendor_gems.rake',
  'version.rake',
  'z_data_dump.rake'].each { |t| load File.join(PACKAGING_PATH, t)}

