namespace :pl do
  desc "Sign the tarball, defaults to PL key, pass GPG_KEY to override or edit build_defaults"
  task :sign_tar do
    unless Pkg::Config.vanagon_project
      tarballs_to_sign = Pkg::Util::Ship.collect_packages(['pkg/*.tar.gz'], ['signing_bundle', 'packaging-bundle'])
      Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')
      tarballs_to_sign.each do |file|
        Pkg::Util::Gpg.sign_file file
      end
    end
  end

  # If no directory to sign is specified assume "pkg"
  $DEFAULT_DIRECTORY = "pkg"

  desc "Sign the Arista EOS swix packages, defaults to PL key, pass GPG_KEY to override or edit build_defaults"
  task :sign_swix, :root_dir do |_t, args|
    swix_dir = args.root_dir || $DEFAULT_DIRECTORY
    packages = Dir["#{swix_dir}/**/*.swix"]
    unless packages.empty?
      Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')
      packages.each do |swix_package|
        Pkg::Util::Gpg.sign_file swix_package
      end
    end
  end

  desc "Detach sign any solaris svr4 packages"
  task :sign_svr4, :root_dir do |_t, args|
    svr4_dir = args.root_dir || $DEFAULT_DIRECTORY
    unless Dir["#{svr4_dir}/**/*.pkg.gz"].empty?
      Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')
      Dir["#{svr4_dir}/**/*.pkg.gz"].each do |pkg|
        Pkg::Util::Gpg.sign_file pkg
      end
    end
  end

  desc "Sign mocked rpms, Defaults to PL Key, pass GPG_KEY to override"
  task :sign_rpms, :root_dir do |t, args|
    rpm_dir = args.root_dir || $DEFAULT_DIRECTORY

    # Create a hash mapping full paths to basenames.
    # This will allow us to keep track of the different paths that may be
    # associated with a single basename, e.g. noarch packages.
    all_rpms = {}
    rpms_to_sign = Dir["#{rpm_dir}/**/*.rpm"]
    rpms_to_sign.each do |rpm_path|
      all_rpms[rpm_path] = File.basename(rpm_path)
    end
    # Delete a package, both from the signing server and from the rpm array, if
    # there are other packages with the same basename so that we only sign the
    # package once.
    all_rpms.each do |rpm_path, rpm_filename|
      if rpms_to_sign.map { |rpm| File.basename(rpm) }.count(rpm_filename) > 1
        FileUtils.rm(rpm_path)
        rpms_to_sign.delete(rpm_path)
      end
    end

    v3_rpms = []
    v4_rpms = []
    rpms_to_sign.each do |rpm|
      platform_tag = Pkg::Paths.tag_from_artifact_path(rpm)
      platform, version, _ = Pkg::Platforms.parse_platform_tag(platform_tag)

      # We don't sign AIX rpms
      next if platform_tag.include?('aix')

      sig_type = Pkg::Platforms.signature_format_for_platform_version(platform, version)
      case sig_type
      when 'v3'
        v3_rpms << rpm
      when 'v4'
        v4_rpms << rpm
      else
        fail "Cannot find signature type for package '#{rpm}'"
      end
    end

    unless v3_rpms.empty?
      puts "Signing old rpms..."
      Pkg::Sign::Rpm.legacy_sign(v3_rpms.join(' '))
    end

    unless v4_rpms.empty?
      puts "Signing modern rpms..."
      Pkg::Sign::Rpm.sign(v4_rpms.join(' '))
    end

    # Using the map of paths to basenames, we re-hardlink the rpms we deleted.
    all_rpms.each do |link_path, rpm_filename|
      next if File.exist? link_path
      FileUtils.mkdir_p(File.dirname(link_path))
      # Find paths where the signed rpm has the same basename, but different
      # full path, as the one we need to link.
      paths_to_link_to = rpms_to_sign.select { |rpm| File.basename(rpm) == rpm_filename && rpm != link_path }
      paths_to_link_to.each do |path|
        FileUtils.ln(path, link_path, :force => true, :verbose => true)
      end
    end
  end

  desc "Sign ips package, uses PL certificates by default, update privatekey_pem, certificate_pem, and ips_inter_cert in build_defaults.yaml to override."
  task :sign_ips, :root_dir do |_t, args|
    ips_dir = args.root_dir || $DEFAULT_DIRECTORY
    Pkg::Sign::Ips.sign(ips_dir) unless Dir["#{ips_dir}/**/*.p5p"].empty?
  end

  desc "Sign built gems, defaults to PL key, pass GPG_KEY to override or edit build_defaults"
  task :sign_gem, :root_dir do |_t, args|
    gems_dir = args.root_dir || $DEFAULT_DIRECTORY
    gems = FileList["#{gems_dir}/*.gem"]
    gems.each do |gem|
      puts "signing gem #{gem}"
      Pkg::Util::Gpg.sign_file(gem)
    end
  end

  desc "Check if all rpms are signed"
  task :check_rpm_sigs, :root_dir do |_t, args|
    rpm_dir = args.root_dir || $DEFAULT_DIRECTORY
    signed = TRUE
    rpms = Dir["#{rpm_dir}/**/*.rpm"]
    print 'Checking rpm signatures'
    rpms.each do |rpm|
      if Pkg::Sign::Rpm.has_sig? rpm
        print '.'
      else
        puts "#{rpm} is unsigned."
        signed = FALSE
      end
    end
    fail unless signed
    puts "All rpms signed"
  end

  desc "Sign generated debian changes files. Defaults to PL Key, pass GPG_KEY to override"
  task :sign_deb_changes, :root_dir do |_t, args|
    begin
      deb_dir = args.root_dir || $DEFAULT_DIRECTORY
      change_files = Dir["#{deb_dir}/**/*.changes"]
      unless change_files.empty?
        Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')
        Pkg::Sign::Deb.sign_changes("#{deb_dir}/**/*.changes")
      end
    ensure
      Pkg::Util::Gpg.kill_keychain
    end
  end

  desc "Sign OSX packages"
  task :sign_osx, [:root_dir] => "pl:fetch" do |_t, args|
    dmg_dir = args.root_dir || $DEFAULT_DIRECTORY
    Pkg::Sign::Dmg.sign(dmg_dir) unless Dir["#{dmg_dir}/**/*.dmg"].empty?
  end

  desc "Sign MSI packages"
  task :sign_msi, [:root_dir] => "pl:fetch" do |_t, args|
    msi_dir = args.root_dir || $DEFAULT_DIRECTORY
    Pkg::Sign::Msi.sign(msi_dir) unless Dir["#{msi_dir}/**/*.msi"].empty?
  end

  ##
  # This crazy piece of work establishes a remote repo on the signing
  # server, ships our packages out to it, signs them, and brings them back.
  #
  namespace :jenkins do
    desc "Sign all locally staged packages on #{Pkg::Config.signing_server}"
    task :sign_all, :root_dir do |_t, args|
      Pkg::Util::RakeUtils.invoke_task('pl:fetch')
      root_dir = args.root_dir || $DEFAULT_DIRECTORY
      Dir["#{root_dir}/*"].empty? and fail "There were no files found in #{root_dir}. Maybe you wanted to build/retrieve something first?"

      # Because rpms and debs are laid out differently in PE under pkg/ they
      # have a different sign task to address this. Rather than create a whole
      # extra :jenkins task for signing PE, we determine which sign task to use
      # based on if we're building PE.
      # We also listen in on the environment variable SIGNING_BUNDLE. This is
      # _NOT_ intended for public use, but rather with the internal promotion
      # workflow for Puppet Enterprise. SIGNING_BUNDLE is the path to a tarball
      # containing a git bundle to be used as the environment for the packaging
      # repo in a signing operation.
      signing_bundle = ENV['SIGNING_BUNDLE']
      rpm_sign_task = Pkg::Config.build_pe ? "pe:sign_rpms" : "pl:sign_rpms"
      deb_sign_task = Pkg::Config.build_pe ? "pe:sign_deb_changes" : "pl:sign_deb_changes"
      sign_tasks    = [rpm_sign_task]
      sign_tasks    << deb_sign_task unless Dir["#{root_dir}/**/*.changes"].empty?
      sign_tasks    << "pl:sign_tar" if Pkg::Config.build_tar
      sign_tasks    << "pl:sign_gem" if Pkg::Config.build_gem
      sign_tasks    << "pl:sign_osx" if Pkg::Config.build_dmg || Pkg::Config.vanagon_project
      sign_tasks    << "pl:sign_swix" if Pkg::Config.vanagon_project
      sign_tasks    << "pl:sign_svr4" if Pkg::Config.vanagon_project
      sign_tasks    << "pl:sign_ips" if Pkg::Config.vanagon_project
      sign_tasks    << "pl:sign_msi" if Pkg::Config.build_msi || Pkg::Config.vanagon_project
      remote_repo   = Pkg::Util::Net.remote_bootstrap(Pkg::Config.signing_server, 'HEAD', nil, signing_bundle)
      build_params  = Pkg::Util::Net.remote_buildparams(Pkg::Config.signing_server, Pkg::Config)
      Pkg::Util::Net.rsync_to(root_dir, Pkg::Config.signing_server, remote_repo)
      rake_command = <<-DOC
cd #{remote_repo} ;
if [[ -r Gemfile ]]; then
  source /usr/local/rvm/scripts/rvm; rvm use ruby-2.4.1; bundle install --path .bundle/gems --binstubs .bundle/bin;
else
  echo "ERROR: Couldn't read Gemfile, can't bundle install."
  exit 1
fi ;
bundle exec rake #{sign_tasks.map { |task| task + "[#{root_dir}]" }.join(" ")} PARAMS_FILE=#{build_params}
DOC
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.signing_server, rake_command)
      Pkg::Util::Net.rsync_from("#{remote_repo}/#{root_dir}/", Pkg::Config.signing_server, "#{$DEFAULT_DIRECTORY}/")
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.signing_server, "rm -rf #{remote_repo}")
      Pkg::Util::Net.remote_ssh_cmd(Pkg::Config.signing_server, "rm #{build_params}")
      puts "Signed packages staged in #{$DEFAULT_DIRECTORY}/ directory"
    end
  end
end
