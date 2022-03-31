module Pkg::Sign::Msi
  module_function

  def sign(target_dir = 'pkg')
    use_identity = "-i #{Pkg::Config.msi_signing_ssh_key}" if Pkg::Config.msi_signing_ssh_key

    ssh_host_string = "#{use_identity} Administrator@#{Pkg::Config.msi_signing_server}"
    rsync_host_string = "-e 'ssh #{use_identity}' Administrator@#{Pkg::Config.msi_signing_server}"

    work_dir = "Windows/Temp/#{Pkg::Util.rand_string}"
    Pkg::Util::Net.remote_execute(ssh_host_string, "mkdir -p C:/#{work_dir}")
    msis = Dir.glob("#{target_dir}/windows*/**/*.msi")
    Pkg::Util::Net.rsync_to(msis.join(" "), rsync_host_string, "/cygdrive/c/#{work_dir}",
                           extra_flags: ["--ignore-existing --relative"])

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
    sign_command = <<~CMD
      for msipath in #{msis.join(' ')}; do
        msi="$(basename $msipath)"
        msidir="C:/#{work_dir}/$(dirname $msipath)"
        if "/cygdrive/c/tools/osslsigncode-fork/osslsigncode.exe" verify -in "$msidir/$msi" ; then
          echo "$msi is already signed, skipping . . ." ;
        else
          tries=5
          sha1Servers=(http://timestamp.digicert.com/sha1/timestamp
          http://timestamp.comodoca.com/authenticode)
          for timeserver in "${sha1Servers[@]}"; do
            for ((try=1; try<=$tries; try++)) do
              ret=$(/cygdrive/c/tools/osslsigncode-fork/osslsigncode.exe sign \
                -n "Puppet" -i "http://www.puppet.com" \
                -h sha1 \
                -pkcs12 "#{Pkg::Config.msi_signing_cert}" \
                -pass "#{Pkg::Config.msi_signing_cert_pw}" \
                -t "$timeserver" \
                -in "$msidir/$msi" \
                -out "$msidir/signed-$msi")
              if [[ $ret == *"Succeeded"* ]]; then break; fi
            done;
            if [[ $ret == *"Succeeded"* ]]; then break; fi
          done;
          echo $ret
          if [[ $ret != *"Succeeded"* ]]; then exit 1; fi
          sha256Servers=(http://timestamp.digicert.com/sha256/timestamp
            http://timestamp.comodoca.com?td=sha256)
          for timeserver in "${sha256Servers[@]}"; do
            for ((try=1; try<=$tries; try++)) do
              ret=$(/cygdrive/c/tools/osslsigncode-fork/osslsigncode.exe sign \
                -n "Puppet" -i "http://www.puppet.com" \
                -nest -h sha256 \
                -pkcs12 "#{Pkg::Config.msi_signing_cert}" \
                -pass "#{Pkg::Config.msi_signing_cert_pw}" \
                -ts "$timeserver" \
                -in "$msidir/signed-$msi" \
                -out "$msidir/$msi")
              if [[ $ret == *"Succeeded"* ]]; then break; fi
            done;
            if [[ $ret == *"Succeeded"* ]]; then break; fi
          done;
          echo $ret
          if [[ $ret != *"Succeeded"* ]]; then exit 1; fi
        fi
      done
    CMD

    Pkg::Util::Net.remote_execute(
      ssh_host_string,
      sign_command,
      { fail_fast: false }
    )
    msis.each do |msi|
      Pkg::Util::Net.rsync_from("/cygdrive/c/#{work_dir}/#{msi}", rsync_host_string, File.dirname(msi))
    end
    Pkg::Util::Net.remote_execute(ssh_host_string, "if [ -d '/cygdrive/c/#{work_dir}' ]; then rm -rf '/cygdrive/c/#{work_dir}'; fi")
  end
end
