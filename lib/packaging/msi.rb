module Pkg::MSI
  class << self
    def sign(target_dir = 'pkg')
      use_identity = "-i #{Pkg::Config.msi_signing_ssh_key}" if Pkg::Config.msi_signing_ssh_key

      ssh_host_string = "#{use_identity} Administrator@#{Pkg::Config.msi_signing_server}"
      rsync_host_string = "-e 'ssh #{use_identity}' Administrator@#{Pkg::Config.msi_signing_server}"

      work_dir = "Windows/Temp/#{Pkg::Util.rand_string}"
      Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "mkdir -p C:/#{work_dir}")
      msis = Dir.glob("#{target_dir}/windows/**/*.msi")
      Pkg::Util::Net.rsync_to(msis.join(" "), rsync_host_string, "/cygdrive/c/#{work_dir}")
      Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, %Q(for msi in #{msis.map { |d| File.basename(d) }.join(" ")}; do
        "/cygdrive/c/tools/osslsigncode-fork/osslsigncode.exe" sign \
          -n "Puppet" -i "http://www.puppetlabs.com" \
          -h sha1 \
          -pkcs12 "#{Pkg::Config.msi_signing_cert}" \
          -pass "#{Pkg::Config.msi_signing_cert_pw}" \
          -t "http://timestamp.verisign.com/scripts/timstamp.dll" \
          -in "C:/#{work_dir}/$msi" \
          -out "C:/#{work_dir}/signed-$msi"
        "/cygdrive/c/tools/osslsigncode-fork/osslsigncode.exe" sign \
          -n "Puppet" -i "http://www.puppetlabs.com" \
          -nest -h sha256 \
          -pkcs12 "#{Pkg::Config.msi_signing_cert}" \
          -pass "#{Pkg::Config.msi_signing_cert_pw}" \
          -ts "http://sha256timestamp.ws.symantec.com/sha256/timestamp" \
          -in "C:/#{work_dir}/signed-$msi" \
          -out "C:/#{work_dir}/$msi"
        rm "C:/#{work_dir}/signed-$msi"
      done))
      msis.each do | msi |
        Pkg::Util::Net.rsync_from("/cygdrive/c/#{work_dir}/#{File.basename(msi)}", rsync_host_string, File.dirname(msi))
      end
      Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "if [ -d '/cygdrive/c/#{work_dir}' ]; then rm -rf '/cygdrive/c/#{work_dir}'; fi")
    end
  end
end
