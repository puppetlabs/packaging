module Pkg::Sign::Ips
  module_function

  def sign(packages_root = 'pkg')
    identity_spec = ''
    unless Pkg::Config.ips_signing_ssh_key.nil?
      identity_spec = "-i #{Pkg::Config.ips_signing_ssh_key}"
    end

    signing_server_spec = Pkg::Config.ips_signing_server
    unless Pkg::Config.ips_signing_server.match(%r{.+@.+})
      signing_server_spec = "#{ENV['USER']}@#{Pkg::Config.ips_signing_server}"
    end

    ssh_host_spec = "#{identity_spec} #{signing_server_spec}"
    rsync_host_spec = "-e 'ssh #{identity_spec}' #{signing_server_spec}"

    packages = Dir.glob("#{packages_root}/solaris/11/**/*.p5p")

    packages.each do |package|
      work_dir     = "/tmp/#{Pkg::Util.rand_string}"
      unsigned_dir = "#{work_dir}/unsigned"
      repo_dir     = "#{work_dir}/repo"
      signed_dir   = "#{work_dir}/pkgs"
      package_name = File.basename(package)

      Pkg::Util::Net.remote_execute(
        ssh_host_spec,
        "mkdir -p #{repo_dir} #{unsigned_dir} #{signed_dir}"
      )
      Pkg::Util::Net.rsync_to(package, rsync_host_spec, unsigned_dir)

      # Before we can get started with signing packages we need to create a repo
      Pkg::Util::Net.remote_execute(ssh_host_spec, "sudo -E /usr/bin/pkgrepo create #{repo_dir}")
      Pkg::Util::Net.remote_execute(
        ssh_host_spec,
        "sudo -E /usr/bin/pkgrepo set -s #{repo_dir} publisher/prefix=puppetlabs.com"
      )

      # Import all the packages into the repo.
      Pkg::Util::Net.remote_execute(
        ssh_host_spec,
        "sudo -E /usr/bin/pkgrecv -s #{unsigned_dir}/#{package_name} -d #{repo_dir} '*'"
      )

      # We sign the entire repo
      # Paths to the  .pem files should live elsewhere rather than hardcoded here.
      sign_cmd = "sudo -E /usr/bin/pkgsign -c /root/signing/signing_cert_2020.pem \
                  -i /root/signing/Thawte_SHA256_Code_Signing_CA.pem \
                  -i /root/signing/Thawte_Primary_Root_CA.pem \
                  -k /root/signing/signing_key_2020.pem \
                  -s 'file://#{work_dir}/repo' '*'"
      puts "Signing #{package} with #{sign_cmd} in #{work_dir}"
      Pkg::Util::Net.remote_execute(ssh_host_spec, sign_cmd.squeeze(' '))

      # pkgrecv with -a will pull packages out of the repo, so we need
      # to do that too to actually get the packages we signed
      Pkg::Util::Net.remote_execute(
        ssh_host_spec,
        "sudo -E /usr/bin/pkgrecv -d #{signed_dir}/#{package_name} -a -s #{repo_dir} '*'"
      )
      begin
        # lets make sure we actually signed something?
        # **NOTE** if we're repeatedly trying to sign the same version this
        # might explode because I don't know how to reset the IPS cache.
        # Everything is amazing.
        Pkg::Util::Net.remote_execute(
          ssh_host_spec,
          "sudo -E /usr/bin/pkg contents -m -g #{signed_dir}/#{package_name} '*' " \
          "| grep '^signature '")
      rescue RuntimeError
        raise "Error: #{package_name} was not signed correctly."
      end

      # Pull the packages back.
      Pkg::Util::Net.rsync_from(
        "#{signed_dir}/#{package_name}",
        rsync_host_spec,
        File.dirname(package)
      )

      Pkg::Util::Net.remote_execute(
        ssh_host_spec,
        "if [ -e '#{work_dir}' ] ; then sudo rm -r '#{work_dir}' ; fi"
      )
    end
  end
end
