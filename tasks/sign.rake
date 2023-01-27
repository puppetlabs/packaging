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
    rpm_directory = args.root_dir || $DEFAULT_DIRECTORY
    Pkg::Sign::Rpm.sign_all(rpm_directory)
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
    signed = true
    rpms = Dir["#{rpm_dir}/**/*.rpm"]
    print 'Checking rpm signatures'
    rpms.each do |rpm|
      if Pkg::Sign::Rpm.has_sig? rpm
        print '.'
      else
        puts "#{rpm} is unsigned."
        signed = false
      end
    end
    fail unless signed
    puts "All rpms signed"
  end

  desc "Sign generated debian changes files. Defaults to PL Key, pass GPG_KEY to override"
  task :sign_deb_changes, :root_dir do |_t, args|
    deb_dir = args.root_dir || $DEFAULT_DIRECTORY
    change_files = Dir["#{deb_dir}/**/*.changes"]
    unless change_files.empty?
      Pkg::Util::Gpg.load_keychain if Pkg::Util::Tool.find_tool('keychain')
      change_files.each do |file|
        Pkg::Sign::Deb.sign_changes(file)
      end
    end
  ensure
    Pkg::Util::Gpg.kill_keychain
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
  namespace :jenkins do
    # The equivalent to invoking this task is calling Pkg::Util::Sign.sign_all(root_directory)
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
      remote_repo   = Pkg::Util::Net.remote_unpack_git_bundle(Pkg::Config.signing_server, 'HEAD', nil, signing_bundle)
      build_params  = Pkg::Util::Net.remote_buildparams(Pkg::Config.signing_server, Pkg::Config)
      Pkg::Util::Net.rsync_to(root_dir, Pkg::Config.signing_server, remote_repo)
      rake_command = <<~DOC
        cd #{remote_repo} ;
        #{Pkg::Util::Net.remote_bundle_install_command}
        bundle exec rake #{sign_tasks.map { |task| task + "[#{root_dir}]" }.join(' ')} PARAMS_FILE=#{build_params}
      DOC
      Pkg::Util::Net.remote_execute(Pkg::Config.signing_server, rake_command)
      Pkg::Util::Net.rsync_from("#{remote_repo}/#{root_dir}/", Pkg::Config.signing_server, "#{root_dir}/")
      Pkg::Util::Net.remote_execute(Pkg::Config.signing_server, "rm -rf #{remote_repo}")
      Pkg::Util::Net.remote_execute(Pkg::Config.signing_server, "rm #{build_params}")
      puts "Signed packages staged in #{root_dir}/ directory"
    end
  end
end
