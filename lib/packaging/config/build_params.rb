require 'packaging/config'

module Pkg
  class Config
    module BuildParams
      LOCK = File.join(Dir.home, ".packaging")
      DATA_REPO = ENV['DATA_REPO'] ||
        'https://raw.githubusercontent.com/puppetlabs/build-data'

      def self.data_url(branch_name)
        str = File.join(DATA_REPO, branch_name, Pkg::Config.builder_data_file)
        URI.parse(str).to_s
      end

      def self.dev_build?
        !!Pkg::Config.dev_build
      rescue NoMethodError
        false
      end

      def self.pe_build?
        !!Pkg::Config.build_pe
      end

      def self.named_pe_build?
        pe_build? && !(Pkg::Config.project =~ /^pe-/)
      end

      def self.named_pe_team?
        pe_build? && !(Pkg::Config.team =~ /^pe-/)
      end

      def self.project_branch
        project_data_branch = [Pkg::Config.project]
        project_data_branch.unshift 'pe-' unless named_pe_build?
        if dev_build?
          warn 'NOTICE: This is a dev build!'
          project_data_branch.push '-dev'
        end
        project_data_branch.join
      end

      def self.team_branch
        team_data_branch = [Pkg::Config.team]
        team_data_branch.unshift 'pe-' unless named_pe_team?
        team_data_branch.join
      end

      # Remove .packaging directory from old-style extras loading
      def self.cleanup
        FileUtils.rm_rf LOCK if File.directory?(LOCK)
      end

      # Touch the .packaging file which is allows packaging to present remote tasks
      def self.present
        FileUtils.touch LOCK
      end

      def self.retrieve
        if dist = Pkg::Util::Version.el_version
          if dist.to_i < 6
            flag = "-k"
          end
        end

        tempdir = Pkg::Util::File.mktemp
        [data_url(team_branch), data_url(project_branch)].each do |url|
          %x(curl --fail --silent #{flag} #{url} > #{tempdir}/#{Pkg::Config.builder_data_file})
          status = $?.exitstatus

          case status
          when 0
            Pkg::Config.load_extras tempdir
          when 22
            if url == data_url(team_branch)
              err = "Could not load team extras data from #{url}. This should not normally happen."
              err += "\nHave you set the TEAM environment variable?"
              fail err
            else
              puts "No build data file for #{Pkg::Config.project}, skipped loading external build data."
            end
          else
            fail "There was an error fetching the builder extras data: '#{url}' (exit code #{status})."
          end
        end
      ensure
        FileUtils.rm_rf tempdir
        Pkg::Config.load_envvars
      end
    end
  end
end
