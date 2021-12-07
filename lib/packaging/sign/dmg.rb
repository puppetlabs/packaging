module Pkg::Sign::Dmg
  module_function

  def sign(pkg_directory = 'pkg')
    use_identity = ''
    unless Pkg::Config.osx_signing_ssh_key.nil?
      use_identity = "-i #{Pkg::Config.osx_signing_ssh_key}"
    end

    host_string = "#{ENV['USER']}@#{Pkg::Config.osx_signing_server}"
    host_string = "#{Pkg::Config.osx_signing_server}" if Pkg::Config.osx_signing_server =~ /@/

    ssh_host_string = "#{use_identity} #{host_string}"
    rsync_host_string = "-e 'ssh #{use_identity}' #{host_string}"
    archs =  Dir.glob("#{pkg_directory}/{apple,mac,osx}/**/{x86_64,arm64}").map { |el| el.split('/').last }

    if archs.empty?
      $stderr.puts "Error: no architectures found in #{pkg_directory}/{apple,mac,osx}"
      exit 1
    end

    archs.each do |arch|
      remote_working_directory = "/tmp/#{Pkg::Util.rand_string}/#{arch}"
      dmg_mount_point = File.join(remote_working_directory, "mount")
      signed_items_directory    = File.join(remote_working_directory, "signed")

      dmgs = Dir.glob("#{pkg_directory}/{apple,mac,osx}/**/#{arch}/*.dmg")
      if dmgs.empty?
        $stderr.puts "Error: no dmgs found in #{pkg_directory}/{apple,mac,osx} for #{arch} architecture."
        exit 1
      end

      dmg_basenames = dmgs.map { |d| File.basename(d, '.dmg') }.join(' ')

      notarization_commands = ''

      if Pkg::Config.notarize_osx
        notarization_commands = %W[
          notarization_command="xcrun altool --notarize-app --primary-bundle-id "$dmg"
            -u $PUPPET_APPLE_DEV_EMAIL -p $PUPPET_APPLE_DEV_PW --asc-provider $ASC_PROVIDER
            --file #{remote_working_directory}/$dmg.dmg" ;
          UUID=$($notarization_command | grep -Ewo '[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}') ;
          notarization_info="xcrun altool --notarization-info $UUID -u $PUPPET_APPLE_DEV_EMAIL -p $PUPPET_APPLE_DEV_PW" ;
          while $notarization_info | grep -q 'in progress'; do
            echo "Waiting on Apple Notarization Service... sleep 10 and try again..." ;
            sleep 10 ;
          done ;
          if $notarization_info | grep -q 'Package Approved'; then
            echo "Package approved by apple notarization service. Stapling ticket to package." ;
            xcrun stapler staple #{remote_working_directory}/$dmg.dmg ;
          else
            echo "Package could not be approved by apple notarization service. Exiting signing process..." ;
            exit 1 ;
          fi ;
          ].join(' ')
      end

      sign_package_command = %W[
        for dmg in #{dmg_basenames}; do
          /usr/bin/hdiutil attach #{remote_working_directory}/$dmg.dmg
            -mountpoint #{dmg_mount_point} -nobrowse -quiet ;

          /usr/bin/security -q unlock-keychain
            -p "#{Pkg::Config.osx_signing_keychain_pw}" "#{Pkg::Config.osx_signing_keychain}" ;

          for pkg in #{dmg_mount_point}/*.pkg; do
            pkg_basename=$(basename $pkg) ;
            if /usr/sbin/pkgutil --check-signature $pkg ; then
              echo "Warning: $pkg is already signed, skipping" ;
              cp $pkg #{signed_items_directory}/$pkg_basename ;
              continue ;
            fi ;

            /usr/bin/productsign --keychain "#{Pkg::Config.osx_signing_keychain}"
              --sign "#{Pkg::Config.osx_signing_cert}"
              $pkg #{signed_items_directory}/$pkg_basename ;
          done ;

          /usr/bin/hdiutil detach #{dmg_mount_point} -quiet ;
          /bin/rm #{remote_working_directory}/$dmg.dmg ;
          /usr/bin/hdiutil create -volname $dmg
            -srcfolder #{signed_items_directory}/ #{remote_working_directory}/$dmg.dmg ;
          /bin/rm #{signed_items_directory}/* ;

          #{notarization_commands}
        done
      ].join(' ')

      Pkg::Util::Net.remote_execute(ssh_host_string,
                                    "mkdir -p #{dmg_mount_point} #{signed_items_directory}")

      Pkg::Util::Net.rsync_to(dmgs.join(' '), rsync_host_string, remote_working_directory)

      Pkg::Util::Net.remote_execute(ssh_host_string, sign_package_command)

      dmgs.each do |dmg|
        Pkg::Util::Net.rsync_from(
          "#{remote_working_directory}/#{File.basename(dmg)}", rsync_host_string, File.dirname(dmg))
      end

      Pkg::Util::Net.remote_execute(ssh_host_string, "rm -rf '#{remote_working_directory}'")
    end
  end
end
