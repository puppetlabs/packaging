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

namespace :pl do
  desc "Sign mocked rpms, Defaults to Puppet Labs Key, pass KEY to override"
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
end

