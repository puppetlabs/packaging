module Pkg::Sign::Dmg
  module_function

  def sign(target_dir = 'pkg')
    use_identity = "-i #{Pkg::Config.osx_signing_ssh_key}" unless Pkg::Config.osx_signing_ssh_key.nil?

    host_string = if Pkg::Config.osx_signing_server =~ /@/
                    Pkg::Config.osx_signing_server.to_s
                  else
                    "#{ENV['USER']}@#{Pkg::Config.osx_signing_server}"
                  end
    ssh_host_string = "#{use_identity} #{host_string}"
    rsync_host_string = "-e 'ssh #{use_identity}' #{host_string}"

    work_dir  = "/tmp/#{Pkg::Util.rand_string}"
    mount     = File.join(work_dir, "mount")
    signed    = File.join(work_dir, "signed")
    Pkg::Util::Net.remote_execute(ssh_host_string, "mkdir -p #{mount} #{signed}")
    dmgs = Dir.glob("#{target_dir}/apple/**/*.dmg")
    Pkg::Util::Net.rsync_to(dmgs.join(" "), rsync_host_string, work_dir)
    Pkg::Util::Net.remote_execute(ssh_host_string, %[for dmg in #{dmgs.map { |d| File.basename(d, '.dmg') }.join(' ')}; do
      /usr/bin/hdiutil attach #{work_dir}/$dmg.dmg -mountpoint #{mount} -nobrowse -quiet ;
      /usr/bin/security -q unlock-keychain -p "#{Pkg::Config.osx_signing_keychain_pw}" "#{Pkg::Config.osx_signing_keychain}" ;
        for pkg in $(ls #{mount}/*.pkg | xargs -n 1 basename); do
          if /usr/sbin/pkgutil --check-signature #{mount}/$pkg ; then
            echo "$pkg is already signed, skipping . . ." ;
            cp #{mount}/$pkg #{signed}/$pkg ;
          else
            /usr/bin/productsign --keychain "#{Pkg::Config.osx_signing_keychain}" --sign "#{Pkg::Config.osx_signing_cert}" #{mount}/$pkg #{signed}/$pkg ;
          fi
        done
      /usr/bin/hdiutil detach #{mount} -quiet ;
      /bin/rm #{work_dir}/$dmg.dmg ;
      /usr/bin/hdiutil create -volname $dmg -srcfolder #{signed}/ #{work_dir}/$dmg.dmg ;
      /bin/rm #{signed}/* ; done])
    dmgs.each do |dmg|
      Pkg::Util::Net.rsync_from("#{work_dir}/#{File.basename(dmg)}", rsync_host_string, File.dirname(dmg))
    end
    Pkg::Util::Net.remote_execute(ssh_host_string, "if [ -d '#{work_dir}' ]; then rm -rf '#{work_dir}'; fi")
  end
end
