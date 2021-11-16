# Module for signing all packages to places


module Pkg::Util::Sign
  class << self
    # Sign all locally staged packages on signing server.
    def sign_all(root_directory=nil)
      Pkg::Util::File.fetch
      root_directory = root_directory || ENV['DEFAULT_DIRECTORY']
      Dir["#{root_directory}/*"].empty? and fail "There were no files found in #{root_directory}. \
      Maybe you wanted to build/retrieve something first?"

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
      sign_tasks    = ["pl:sign_rpms"]
      sign_tasks    << "pl:sign_deb_changes" unless Dir["#{root_directory}/**/*.changes"].empty?
      sign_tasks    << "pl:sign_tar" if Pkg::Config.build_tar
      sign_tasks    << "pl:sign_gem" if Pkg::Config.build_gem
      sign_tasks    << "pl:sign_osx" if Pkg::Config.build_dmg || Pkg::Config.vanagon_project
      sign_tasks    << "pl:sign_swix" if Pkg::Config.vanagon_project
      sign_tasks    << "pl:sign_svr4" if Pkg::Config.vanagon_project
      sign_tasks    << "pl:sign_ips" if Pkg::Config.vanagon_project
      sign_tasks    << "pl:sign_msi" if Pkg::Config.build_msi || Pkg::Config.vanagon_project
      remote_repo   = Pkg::Util::Net.remote_unpack_git_bundle(Pkg::Config.signing_server, 'HEAD', nil, signing_bundle)
      build_params  = Pkg::Util::Net.remote_buildparams(Pkg::Config.signing_server, Pkg::Config)
      Pkg::Util::Net.rsync_to(root_directory, Pkg::Config.signing_server, remote_repo)
      rake_command = <<-DOC
cd #{remote_repo} ;
#{Pkg::Util::Net.remote_bundle_install_command}
bundle exec rake #{sign_tasks.map { |task| task + "[#{root_directory}]" }.join(" ")} PARAMS_FILE=#{build_params}
DOC
      Pkg::Util::Net.remote_execute(Pkg::Config.signing_server, rake_command)
      Pkg::Util::Net.rsync_from("#{remote_repo}/#{root_directory}/", Pkg::Config.signing_server, "#{root_directory}/")
      Pkg::Util::Net.remote_execute(Pkg::Config.signing_server, "rm -rf #{remote_repo}")
      Pkg::Util::Net.remote_execute(Pkg::Config.signing_server, "rm #{build_params}")
      puts "Signed packages staged in #{root_directory}/ directory"
    end
  end
end