module Pkg::Nuget
  class << self
    def ship(packages)
      #
      # Support shipping of Nuget style packages to a nexus based nuget feed
      # Using curl to submit the packages rather than windows based choco/mono.
      # This approach gives more flexibility and fits in with the current Puppet
      # release automation practices using linux/mac systems.

      # Sanity checks
      fail "NUGET_HOST is not defined" if Pkg::Config.nuget_host.empty?
      fail "NUGET_REPO is not defined" if Pkg::Config.nuget_repo_path.to_s.empty?

      # Retrieve password without revealing it
      puts "Obtaining credentials to ship to nuget feed #{Pkg::Config.nuget_repo_path} on #{Pkg::Config.nuget_host}"
      print "Username please: "
      username = Pkg::Util.get_input(true)
      print "Password please: "
      password = Pkg::Util.get_input(false)
      authentication = Pkg::Util.base64_encode("#{username}:#{password}")

      uri = "#{Pkg::Config.nuget_host}#{Pkg::Config.nuget_repo_path}"
      form_data = ["-H 'Authorization: Basic #{authentication}'", "-f"]
      packages.each do |pkg|
        puts "Working on package #{pkg}"
        projname, version = File.basename(pkg).match(/^(.*)-([\d+\.]+)\.nupkg$/).captures
        package_form_data = ["--upload-file #{pkg}"]
        package_path = "#{projname}/#{version}/#{File.basename(pkg)}"
        stdout = ''
        retval = ''
        Pkg::Util::Execution.retry_on_fail(:times => 3) do
          stdout, retval = Pkg::Util::Net.curl_form_data("#{uri}/#{package_path}", form_data + package_form_data)
        end
        fail "The Package upload (curl) failed with error #{retval}" unless Pkg::Util::Execution.success?(retval)
        stdout
      end
    end
  end
end
