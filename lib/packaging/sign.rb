module Pkg::Sign
  module_function

  def sign_rpm(rpm, sign_flags = nil)
    # To enable support for wrappers around rpm and thus support for gpg-agent
    # rpm signing, we have to be able to tell the packaging repo what binary to
    # use as the rpm signing tool.
    rpm_command = ENV['RPM'] || Pkg::Util::Tool.find_tool('rpm')

    # If we're using the gpg agent for rpm signing, we don't want to specify the
    # input for the passphrase, which is what '--passphrase-fd 3' does. However,
    # if we're not using the gpg agent, this is required, and is part of the
    # defaults on modern rpm. The fun part of gpg-agent signing of rpms is
    # specifying that the gpg check command always return true
    gpg_check_command = ''
    input_flag = ''
    if Pkg::Util.boolean_value(ENV['RPM_GPG_AGENT'])
      gpg_check_command = "--define '%__gpg_check_password_command /bin/true'"
    else
      input_flag = "--passphrase-fd 3"
    end

    # Try this up to 5 times, to allow for incorrect passwords
    Pkg::Util::Execution.retry_on_fail(:times => 5) do
      # This definition of %__gpg_sign_command is the default on modern rpm. We
      # accept extra flags to override certain signing behavior for older
      # versions of rpm, e.g. specifying V3 signatures instead of V4.
      %x(#{rpm_command} #{gpg_check_command} --define '%_gpg_name #{Pkg::Util::Gpg.key}' --define '%__gpg_sign_command %{__gpg} gpg #{sign_flags} #{input_flag} --batch --no-verbose --no-armor --no-secmem-warning -u %{_gpg_name} -sbo %{__signature_filename} %{__plaintext_filename}' --addsign #{rpm})
    end
  end

  def sign_legacy_rpm(rpm)
    sign_rpm(rpm, "--force-v3-sigs --digest-algo=sha1")
  end

  def rpm_has_sig(rpm)
    %x(rpm -Kv #{rpm} | grep "#{Pkg::Util::Gpg.key.downcase}" &> /dev/null)
    $?.success?
  end

  def sign_deb_changes(file)
    # Lazy lazy lazy lazy lazy
    sign_program = "-p'gpg --use-agent --no-tty'" if ENV['RPM_GPG_AGENT']
    %x(debsign #{sign_program} --re-sign -k#{Pkg::Config.gpg_key} #{file})
  end

  def sign_msi(target_dir = 'pkg')
    use_identity = "-i #{Pkg::Config.msi_signing_ssh_key}" if Pkg::Config.msi_signing_ssh_key

    ssh_host_string = "#{use_identity} Administrator@#{Pkg::Config.msi_signing_server}"
    rsync_host_string = "-e 'ssh #{use_identity}' Administrator@#{Pkg::Config.msi_signing_server}"

    work_dir = "Windows/Temp/#{Pkg::Util.rand_string}"
    Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "mkdir -p C:/#{work_dir}")
    msis = Dir.glob("#{target_dir}/windows/**/*.msi")
    Pkg::Util::Net.rsync_to(msis.join(" "), rsync_host_string, "/cygdrive/c/#{work_dir}")

    # Please Note:
    # We are currently adding two signatures to the msi.
    #
    # Microsoft compatable Signatures are composed of three different
    # elements.
    #   1) The Certificate used to sign the package. This is the element that
    #     is attached to organization. The certificate has an associated
    #     algorithm. We recently (February 2016) had to switch from a sha1 to
    #     a sha256 certificate. Sha1 was deprecated by many Microsoft
    #     elements on 2016-01-01, which forced us to switch to a sha256 cert.
    #     This sha256 certificate is recognized by all currently supported
    #     windows platforms (Windows 8/Vista forward).
    #   2) The signature used to attach the certificate to the package. This
    #     can be a done with a variety of digest algorithms. Older platforms
    #     (i.e., Windows 8 and Windows Vista) don't recognize later
    #     algorithms like sha256.
    #   3) The timestamp used to validate when the package was signed. This
    #     comes from an external source and can be delivered with a variety
    #     of digest algorithms. Older platforms do not recognize newer
    #     algorithms like sha256.
    #
    # We could have only one signature with the Sha256 Cert, Sha1 Signature,
    # and Sha1 Timestamp, but that would be too easy. The sha256 signature
    # and timestamp add more security to our packages. We can't have only
    # sha256 elements in our package signature, though, because Windows 8
    # and Windows Vista just don't recognize them at all.
    #
    # In order to add two signatures to an MSI, we also need to change the
    # tool we use to sign packages with. Previously, we were using SignTool
    # which is the Microsoft blessed program used to sign packages. However,
    # this tool isn't able to add two signatures to an MSI specifically. It
    # can dual-sign an exe, just not an MSI. In order to get the dual-signed
    # packages, we decided to switch over to using osslsigncode. The original
    # project didn't have support to compile on a windows system, so we
    # decided to use this fork. The binaries on the signer were pulled from
    # https://sourceforge.net/u/keeely/osslsigncode/ci/master/tree/
    #
    # These are our signatures:
    # The first signature:
    #   * Sha256 Certificate
    #   * Sha1 Signature
    #   * Sha1 Timestamp
    #
    # The second signature:
    #   * Sha256 Certificate
    #   * Sha256 Signature
    #   * Sha256 Timestamp
    #
    # Once we no longer support Windows 8/Windows Vista, we can remove the
    # first Sha1 signature.
    Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, %Q(for msi in #{msis.map { |d| File.basename(d) }.join(" ")}; do
      "/cygdrive/c/tools/osslsigncode-fork/osslsigncode.exe" sign \
        -n "Puppet" -i "http://www.puppet.com" \
        -h sha1 \
        -pkcs12 "#{Pkg::Config.msi_signing_cert}" \
        -pass "#{Pkg::Config.msi_signing_cert_pw}" \
        -t "http://timestamp.verisign.com/scripts/timstamp.dll" \
        -in "C:/#{work_dir}/$msi" \
        -out "C:/#{work_dir}/signed-$msi"
      "/cygdrive/c/tools/osslsigncode-fork/osslsigncode.exe" sign \
        -n "Puppet" -i "http://www.puppet.com" \
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

  def sign_osx(target_dir = 'pkg')
    use_identity = "-i #{Pkg::Config.osx_signing_ssh_key}" unless Pkg::Config.osx_signing_ssh_key.nil?

    if Pkg::Config.osx_signing_server =~ /@/
      host_string = "#{Pkg::Config.osx_signing_server}"
    else
      host_string = "#{ENV['USER']}@#{Pkg::Config.osx_signing_server}"
    end
    ssh_host_string = "#{use_identity} #{host_string}"
    rsync_host_string = "-e 'ssh #{use_identity}' #{host_string}"

    work_dir  = "/tmp/#{Pkg::Util.rand_string}"
    mount     = File.join(work_dir, "mount")
    signed    = File.join(work_dir, "signed")
    Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "mkdir -p #{mount} #{signed}")
    dmgs = Dir.glob("#{target_dir}/apple/**/*.dmg")
    Pkg::Util::Net.rsync_to(dmgs.join(" "), rsync_host_string, work_dir)
    Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, %Q[for dmg in #{dmgs.map { |d| File.basename(d, ".dmg") }.join(" ")}; do
      /usr/bin/hdiutil attach #{work_dir}/$dmg.dmg -mountpoint #{mount} -nobrowse -quiet ;
      /usr/bin/security -q unlock-keychain -p "#{Pkg::Config.osx_signing_keychain_pw}" "#{Pkg::Config.osx_signing_keychain}" ;
        for pkg in $(ls #{mount}/*.pkg | xargs -n 1 basename); do
          /usr/bin/productsign --keychain "#{Pkg::Config.osx_signing_keychain}" --sign "#{Pkg::Config.osx_signing_cert}" #{mount}/$pkg #{signed}/$pkg ;
        done
      /usr/bin/hdiutil detach #{mount} -quiet ;
      /bin/rm #{work_dir}/$dmg.dmg ;
      /usr/bin/hdiutil create -volname $dmg -srcfolder #{signed}/ #{work_dir}/$dmg.dmg ;
      /bin/rm #{signed}/* ; done])
    dmgs.each do | dmg |
      Pkg::Util::Net.rsync_from("#{work_dir}/#{File.basename(dmg)}", rsync_host_string, File.dirname(dmg))
    end
    Pkg::Util::Net.remote_ssh_cmd(ssh_host_string, "if [ -d '#{work_dir}' ]; then rm -rf '#{work_dir}'; fi")
  end

  def sign_ips(target_dir = 'pkg')
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
