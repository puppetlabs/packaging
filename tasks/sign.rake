def sign_el5(rpm)
  %x{rpm --define '%_gpg_name #{@gpg_name}' --define '%__gpg_sign_cmd %{__gpg} gpg --force-v3-sigs --digest-algo=sha1 --batch --no-verbose --no-armor --passphrase-fd 3 --no-secmem-warning -u %{_gpg_name} -sbo %{__signature_filename} %{__plaintext_filename}' --addsign #{rpm} > /dev/null}
end

def sign_modern(rpm)
  %x{rpm --define '%_gpg_name #{@gpg_name}' --addsign #{rpm} > /dev/null}
end

def rpm_has_sig(rpm)
  %x{rpm -Kv #{rpm} | grep "#{@gpg_key.downcase}" &> /dev/null}
  $?.success?
end

def sign_deb_changes(file)
  %x{debsign --re-sign -k#{@gpg_key} #{file}}
end

namespace :pl do
  desc "Sign the tarball, defaults to PL key, pass GPG_KEY to override or edit build_defaults"
  task :sign_tar do
    unless File.exist? "pkg/#{@name}-#{@version}.tar.gz"
      STDERR.puts "No tarball exists. Try rake package:tar?"
      exit 1
    end
    gpg_sign_file "pkg/#{@name}-#{@version}.tar.gz"
  end

  desc "Sign mocked rpms, Defaults to PL Key, pass KEY to override"
  task :sign_rpms do
    el5_rpms    = Dir["pkg/el/5/**/*.rpm"].join(' ')
    modern_rpms = (Dir["pkg/el/6/**/*.rpm"] + Dir["pkg/fedora/**/*.rpm"]).join(' ')
    puts "Signing el5 rpms..."
    sign_el5 el5_rpms
    puts "Signing el6 and fedora rpms..."
    sign_modern modern_rpms
  end

  desc "Check if all rpms are signed"
  task :check_rpm_sigs do
    signed = TRUE
    rpms = Dir["pkg/el/5/**/*.rpm"] + Dir["pkg/el/6/**/*.rpm"] + Dir["pkg/fedora/**/*.rpm"]
    print 'Checking rpm signatures'
    rpms.each do |rpm|
      if rpm_has_sig rpm
        print '.'
      else
        puts "#{rpm} is unsigned."
        signed = FALSE
      end
    end
    exit 1 unless signed
    puts "All rpms signed"
  end

  desc "Sign generated debian changes files."
  task :sign_deb_changes do
    sign_deb_changes("pkg/deb/*/*.changes") unless Dir["pkg/deb/*/*.changes"].empty?
    sign_deb_changes("pkg/deb/*.changes") unless Dir["pkg/deb/*.changes"].empty?
  end
end

