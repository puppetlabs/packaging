module Pkg::Nuget
  class << self
    def ship(packages)
      # Retrieve password without revealing it
      puts "Obtaining credentials to ship to nuget repo on #{Pkg::Config.nuget_host}"
      print "Username please: "
      username = Pkg::Util.get_input(true)
      print "Password please: "
      password = Pkg::Util.get_input(false)
      authentication = Pkg::Util.base64_encode("#{username}:#{password}")

      uri = "#{Pkg::Config.nuget_host}:8081/content/repositories/#{Pkg::Config.nuget_repo_path}"
      form_data = ["-H 'Authorization: Basic #{authentication}'", "-v"]
      packages.each do |pkg|
        package_form_data = ["--upload-file #{pkg}"]
        name, version = pkg.match(/^(.*)\.(\d\.\d\.\d\.\d)\.nupkg$/).captures
        package_path = "#{name}/#{version}/#{pkg}"
        Pkg::Util::Execution.retry_on_fail(:times => 3) do
          Pkg::Util::Net.curl_form_data("#{uri}/#{package_path}", form_data + package_form_data)
        end
      end
    end
  end
end
