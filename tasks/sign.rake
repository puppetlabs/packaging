def sign_el5(rpm)
  # Try this up to 5 times, to allow for incorrect passwords
  retry_on_fail(:times => 5) do
    sh "rpm --define '%_gpg_name #{@build.gpg_name}' --define '%__gpg_sign_cmd %{__gpg} gpg --force-v3-sigs --digest-algo=sha1 --batch --no-verbose --no-armor --passphrase-fd 3 --no-secmem-warning -u %{_gpg_name} -sbo %{__signature_filename} %{__plaintext_filename}' --addsign #{rpm} > /dev/null"
  end
end

def sign_modern(rpm)
  retry_on_fail(:times => 5) do
    sh "rpm --define '%_gpg_name #{@build.gpg_name}' --addsign #{rpm} > /dev/null"
  end
end

def rpm_has_sig(rpm)
  %x{rpm -Kv #{rpm} | grep "#{@build.gpg_key.downcase}" &> /dev/null}
  $?.success?
end

def sign_deb_changes(file)
  %x{debsign --re-sign -k#{@build.gpg_key} #{file}}
end

# requires atleast a self signed prvate key and certificate pair
# fmri is the full IPS package name with version, e.g.
# facter@facter@1.6.15,5.11-0:20121112T042120Z
# technically this can be any ips-compliant package identifier, e.g. application/facter
# repo_uri is the path to the repo currently containing the package
def sign_ips(fmri, repo_uri)
  %x{pkgsign -s #{repo_uri}  -k #{@build.privatekey_pem} -c #{@build.certificate_pem} -i #{@build.ips_inter_cert} #{fmri}}
end

namespace :pl do
  desc "Sign the tarball, defaults to PL key, pass GPG_KEY to override or edit build_defaults"
  task :sign_tar do
    File.exist?("pkg/#{@build.project}-#{@build.version}.tar.gz") or fail "No tarball exists. Try rake package:tar?"
    load_keychain if has_tool('keychain')
    gpg_sign_file "pkg/#{@build.project}-#{@build.version}.tar.gz"
  end

  desc "Sign mocked rpms, Defaults to PL Key, pass KEY to override"
  task :sign_rpms do
    # Find x86_64 noarch rpms that have been created as hard links and remove them
    rm_r Dir["pkg/*/*/*/x86_64/*.noarch.rpm"]
    # We'll sign the remaining noarch
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
    # Now we hardlink them back in
    Dir["pkg/*/*/*/i386/*.noarch.rpm"].each do |rpm|
      cd File.dirname(rpm) do
        ln rpm, File.join("..","x86_64")
      end
    end
  end

  desc "Sign ips package, Defaults to PL Key, pass KEY to override"
  task :sign_ips, :repo_uri, :fmri do |t, args|
    repo_uri  = args.repo_uri
    fmri      = args.fmri
    puts "Signing ips packages..."
    sign_ips(fmri, repo_uri)
  end if @build.build_ips

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
    fail unless signed
    puts "All rpms signed"
  end

  desc "Sign generated debian changes files. Defaults to PL Key, pass KEY to override"
  task :sign_deb_changes do
    begin
      load_keychain if has_tool('keychain')
      sign_deb_changes("pkg/deb/*/*.changes") unless Dir["pkg/deb/*/*.changes"].empty?
      sign_deb_changes("pkg/deb/*.changes") unless Dir["pkg/deb/*.changes"].empty?
    ensure
      %x{keychain -k mine}
    end
  end

  ##
  # This crazy piece of work establishes a remote repo on the distribution
  # server, ships our packages out to it, signs them, and brings them back.
  #
  namespace :jenkins do
    desc "Sign all locally staged packages on #{@build.distribution_server}"
    task :sign_all => "pl:fetch" do
      Dir["pkg/*"].empty? and fail "There were files found in pkg/. Maybe you wanted to build/retrieve something first?"

      # Because rpms and debs are laid out differently in PE under pkg/ they
      # have a different sign task to address this. Rather than create a whole
      # extra :jenkins task for signing PE, we determine which sign task to use
      # based on if we're building PE
      rpm_sign_task = @build.build_pe ? "pe:sign_rpms" : "pl:sign_rpms"
      deb_sign_task = @build.build_pe ? "pe:sign_deb_changes" : "pl:sign_deb_changes"
      sign_tasks    = ["pl:sign_tar", rpm_sign_task, deb_sign_task]
      remote_repo   = remote_bootstrap(@build.distribution_server, 'HEAD')
      build_params  = remote_buildparams(@build.distribution_server, @build)
      rsync_to('pkg', @build.distribution_server, remote_repo)
      remote_ssh_cmd(@build.distribution_server, "cd #{remote_repo} ; rake #{sign_tasks.join(' ')} PARAMS_FILE=#{build_params}")
      rsync_from("#{remote_repo}/pkg/", @build.distribution_server, "pkg/")
      remote_ssh_cmd(@build.distribution_server, "rm -rf #{remote_repo}")
      remote_ssh_cmd(@build.distribution_server, "rm #{build_params}")
      puts "Signed packages staged in 'pkg/ directory"
    end
  end
end

