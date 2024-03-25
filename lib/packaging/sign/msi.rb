module Pkg::Sign::Msi
  module_function

  def sign(packages_root = 'pkg')
    # These will need to be untangled in another release because build-data changes
    # don't affect existing packages
    signing_server_spec = 'jenkins@msi-signer-prod-1.delivery.puppetlabs.net'
    # signing_server_spec = Pkg::Config.msi_signing_server

    identity_spec = '-i /home/jenkins/.ssh/id_signing'
    # identity_spec = "-i #{Pkg::Config.msi_signing_ssh_key}"

    rsync_host_spec = "-e 'ssh #{identity_spec}' #{signing_server_spec}"
    ssh_host_spec = "#{identity_spec} #{signing_server_spec}"

    packages = Dir.glob("#{packages_root}/windows*/**/*.msi")

    packages.each do |package|
      top_directory = "/tmp/#{Pkg::Util.rand_string}"
      unsigned_packages_directory = "#{top_directory}/unsigned"
      signed_packages_directory = "#{top_directory}/pkgs"
      package_name = File.basename(package)
      sign_msi_command = %W[
        /usr/local/bin/sign-msi
        #{unsigned_packages_directory}
        #{signed_packages_directory}
        #{package_name}
      ].join(' ')

      # Send the unsigned package to the signing server
      Pkg::Util::Net.remote_execute(ssh_host_spec, "mkdir -p #{unsigned_packages_directory}")
      Pkg::Util::Net.rsync_to(package, rsync_host_spec, unsigned_packages_directory)

      # Sign it
      puts "Signing #{package} with \"#{sign_msi_command}\""
      Pkg::Util::Net.remote_execute(ssh_host_spec, sign_msi_command)

      # Pull the signed package back
      Pkg::Util::Net.rsync_from(
        "#{signed_packages_directory}/#{package_name}",
        rsync_host_spec,
        File.dirname(package)
      )

      # Clean up
      Pkg::Util::Net.remote_execute(ssh_host_spec, "rm -r '#{top_directory}'")
    end
  end
end
