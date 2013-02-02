def sign_el5(rpm)
  # Try this up to 5 times, to allow for incorrect passwords
  retry_on_fail(:times => 5) do
    sh "rpm --define '%_gpg_name #{@gpg_name}' --define '%__gpg_sign_cmd %{__gpg} gpg --force-v3-sigs --digest-algo=sha1 --batch --no-verbose --no-armor --passphrase-fd 3 --no-secmem-warning -u %{_gpg_name} -sbo %{__signature_filename} %{__plaintext_filename}' --addsign #{rpm} > /dev/null"
  end
end

def sign_modern(rpm)
  retry_on_fail(:times => 5) do
    sh "rpm --define '%_gpg_name #{@gpg_name}' --addsign #{rpm} > /dev/null"
  end
end

def rpm_has_sig(rpm)
  %x{rpm -Kv #{rpm} | grep "#{@gpg_key.downcase}" &> /dev/null}
  $?.success?
end

def sign_deb_changes(file)
  %x{debsign --re-sign -k#{@gpg_key} #{file}}
end

# requires atleast a self signed prvate key and certificate pair
# fmri is the full IPS package name with version, e.g.
# facter@facter@1.6.15,5.11-0:20121112T042120Z
# technically this can be any ips-compliant package identifier, e.g. application/facter
# repo_uri is the path to the repo currently containing the package
def sign_ips(fmri, repo_uri)
  %x{pkgsign -s #{repo_uri}  -k #{@privatekey_pem} -c #{@certificate_pem} -i #{@ips_inter_cert} #{fmri}}
end

namespace :pl do
  desc "Sign the tarball, defaults to PL key, pass GPG_KEY to override or edit build_defaults"
  task :sign_tar do
    unless File.exist? "pkg/#{@name}-#{@version}.tar.gz"
      STDERR.puts "No tarball exists. Try rake package:tar?"
      exit 1
    end
    load_keychain if has_tool('keychain')
    gpg_sign_file "pkg/#{@name}-#{@version}.tar.gz"
  end

  desc "Sign mocked rpms, Defaults to PL Key, pass KEY to override"
  task :sign_rpms do
    el5_rpms    = Dir["pkg/el/5/**/*.rpm"].join(' ')
    modern_rpms = (Dir["pkg/el/6/**/*.rpm"] + Dir["pkg/fedora/**/*.rpm"]).join(' ')
    unless el5_rpms.empty?
      puts "Signing el5 rpms..."
      sign_el5(el5_rpms)
    end

    unless modern_rpms.empty?
      puts "Signing el6 and fedora rpms..."
      sign_modern(modern_rpms)
    end
  end

  desc "Sign ips package, Defaults to PL Key, pass KEY to override"
  task :sign_ips, :repo_uri, :fmri do |t, args|
    repo_uri  = args.repo_uri
    fmri      = args.fmri
    puts "Signing ips packages..."
    sign_ips(fmri, repo_uri)
  end if @build_ips

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

  desc "Sign generated debian changes files. Defaults to PL Key, pass KEY to override"
  task :sign_deb_changes do
    load_keychain if has_tool('keychain')
    sign_deb_changes("pkg/deb/*/*.changes") unless Dir["pkg/deb/*/*.changes"].empty?
    sign_deb_changes("pkg/deb/*.changes") unless Dir["pkg/deb/*.changes"].empty?
  end
end

