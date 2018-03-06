module Pkg::IPS
  class << self
    def sign(target_dir = 'pkg')
      use_identity = "-i #{Pkg::Config.ips_signing_ssh_key}" unless Pkg::Config.ips_signing_ssh_key.nil?

      ssh_host_string = "#{use_identity} #{ENV['USER']}@#{Pkg::Config.ips_signing_server}"
      rsync_host_string = "-e 'ssh #{use_identity}' #{ENV['USER']}@#{Pkg::Config.ips_signing_server}"

      p5ps = Dir.glob("#{target_dir}/solaris/11/**/*.p5p")

      p5ps.each do |p5p|
        work_dir     = "/tmp/#{Pkg::Util.rand_string}"
        unsigned_dir = "#{work_dir}/unsigned"
        repo_dir     = "#{work_dir}/repo"
        signed_dir   = "#{work_dir}/pkgs"

        Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "mkdir -p #{repo_dir} #{unsigned_dir} #{signed_dir}")
        Pkg::Util::Net.rsync_to(p5p, rsync_host_string, unsigned_dir)

        # Before we can get started with signing packages we need to create a repo
        Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "sudo -E /usr/bin/pkgrepo create #{repo_dir}")
        Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "sudo -E /usr/bin/pkgrepo set -s #{repo_dir} publisher/prefix=puppetlabs.com")
        # And import all the packages into the repo.
        Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "sudo -E /usr/bin/pkgrecv -s #{unsigned_dir}/#{File.basename(p5p)} -d #{repo_dir} '*'")
        # We are going to hard code the values for signing cert locations for now.
        # This autmation will require an update to actually become reusable, but
        # for now these values will stay this way so solaris signing will stop
        # failing. Please update soon. 06/23/16
        #
        #            - Sean P. McDonald
        #
        # We sign the entire repo
        sign_cmd = "sudo -E /usr/bin/pkgsign -c /root/signing/signing_cert_2018.pem \
                    -i /root/signing/Thawte_SHA256_Code_Signing_CA.pem \
                    -i /root/signing/Thawte_Primary_Root_CA.pem \
                    -k /root/signing/signing_key_2018.pem \
                    -s 'file://#{work_dir}/repo' '*'"
        puts "About to sign #{p5p} with #{sign_cmd} in #{work_dir}"
        Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, sign_cmd.squeeze(' '))
        # pkgrecv with -a will pull packages out of the repo, so we need to do that too to actually get the packages we signed
        Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "sudo -E /usr/bin/pkgrecv -d #{signed_dir}/#{File.basename(p5p)} -a -s #{repo_dir} '*'")
        begin
          # lets make sure we actually signed something?
          # **NOTE** if we're repeatedly trying to sign the same version this
          # might explode because I don't know how to reset the IPS cache.
          # Everything is amazing.
          Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "sudo -E /usr/bin/pkg contents -m -g #{signed_dir}/#{File.basename(p5p)} '*' | grep '^signature '")
        rescue RuntimeError
          raise "Looks like #{File.basename(p5p)} was not signed correctly, quitting!"
        end
        # and pull the packages back.
        Pkg::Util::Net.rsync_from("#{signed_dir}/#{File.basename(p5p)}", rsync_host_string, File.dirname(p5p))
        Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "if [ -e '#{work_dir}' ] ; then sudo rm -r '#{work_dir}' ; fi")
      end
    end
  end
end
