# Utility methods used for versioning projects for various kinds of packaging
require 'json'

module Pkg::Util::Version
  class << self

    # This is used to set Pkg::Config.version
    def get_dash_version
      if info = Pkg::Util::Git.git_describe_version
        info.join('-')
      end
    end

    def get_dot_version
      Pkg::Config.version.sub('-','.')
    end

    def get_base_pkg_version
      dash = Pkg::Config.version
      if dash.include?("rc")
        # Grab the rc number
        rc_num = dash.match(/rc(\d+)/)[1]
        ver = dash.sub(/-?rc[0-9]+/, "-0.#{Pkg::Config.release}rc#{rc_num}").gsub(/(rc[0-9]+)-(\d+)?-?/, '\1.\2')
      elsif dash.include?("SNAPSHOT")
        # Insert -0.#{release} between the version and the SNAPSHOT string
        ver = dash.sub(/^(.*)\.(SNAPSHOT\..*)$/, "\\1-0.#{Pkg::Config.release}\\2")
      else
        ver = dash.gsub('-', '.') + "-#{Pkg::Config.release}"
      end

      ver.split('-')
    end

    # Determines if this package is a final package via the
    # selected version_strategy.
    # There are currently two supported version strategies.
    #
    # This method calls down to the version strategy indicated, defaulting to the
    # rc_final strategy. The methods themselves will return false if it is a final
    # release, so their return values are collected and then inverted before being
    # returned.
    def is_final?
      case Pkg::Config.version
      when /rc/
        false
      when /SNAPSHOT/
        false
      when /-dirty/
        false
      when /g[a-f0-9]{7}$/
        false
      else
        true
      end
    end

    # This is to support packages that only burn-in the version number in the
    # release artifact, rather than storing it two (or more) times in the
    # version control system.  Razor is a good example of that; see
    # https://github.com/puppetlabs/Razor/blob/master/lib/project_razor/version.rb
    # for an example of that this looks like.
    #
    # If you invoke this the version will only be modified in the temporary copy,
    # with the intent that it never change the official source tree.
    def versionbump(workdir = nil)
      version = ENV['VERSION'] || Pkg::Config.version.to_s.strip
      new_version = '"' + version + '"'

      version_file = "#{workdir ? workdir + '/' : ''}#{Pkg::Config.version_file}"

      # Read the previous version file in...
      contents = IO.read(version_file)

      # Match version files containing 'VERSION = "x.x.x"' and just x.x.x
      if version_string = contents.match(/VERSION =.*/)
        old_version = version_string.to_s.split[-1]
      else
        old_version = contents
      end

      puts "Updating #{old_version} to #{new_version} in #{version_file}"
      if contents.match("@DEVELOPMENT_VERSION@")
        contents.gsub!("@DEVELOPMENT_VERSION@", version)
      elsif contents.match('version\s*=\s*[\'"]DEVELOPMENT[\'"]')
        contents.gsub!(/version\s*=\s*['"]DEVELOPMENT['"]/, "version = '#{version}'")
      elsif contents.match("VERSION = #{old_version}")
        contents.gsub!("VERSION = #{old_version}", "VERSION = #{new_version}")
      elsif contents.match("#{Pkg::Config.project.upcase}VERSION = #{old_version}")
        contents.gsub!("#{Pkg::Config.project.upcase}VERSION = #{old_version}", "#{Pkg::Config.project.upcase}VERSION = #{new_version}")
      else
        contents.gsub!(old_version, Pkg::Config.version)
      end

      # ...and write it back on out.
      File.open(version_file, 'w') { |f| f.write contents }
    end

    # Human readable output for json tags reporting. This will load the
    # input json file and output if it "looks tagged" or not
    #
    # @param json_data [hash] json data hash containing the ref to check
    def report_json_tags(json_data)
      puts "component: " + File.basename(json_data["url"])
      puts "ref: " + json_data["ref"].to_s
      if Pkg::Util::Git.remote_tagged?(json_data["url"], json_data["ref"].to_s)
        tagged = "Tagged? [ Yes ]"
      else
        tagged = "Tagged? [ No  ]"
      end
      col_len = (ENV["COLUMNS"] || 70).to_i
      puts format("\n%#{col_len}s\n\n", tagged)
      puts ("*" * col_len)
    end

  end
end
