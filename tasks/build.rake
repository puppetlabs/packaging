module Build
  ##
  # This class is meant to encapsulate all of the data we know about a build invoked with
  # `rake package:<build>` or `rake pl:<build>`. It can read in this data via a yaml file,
  # have it set via accessors, and serialize it back to yaml for easy transport.
  #
  class BuildInstance
    @@build_params = [:apt_host,
                      :apt_repo_path,
                      :apt_repo_url,
                      :author,
                      :benchmark,
                      :build_date,
                      :build_defaults,
                      :build_dmg,
                      :build_doc,
                      :build_gem,
                      :build_ips,
                      :build_pe,
                      :builder_data_file,
                      :builds_server,
                      :certificate_pem,
                      :cows,
                      :db_table,
                      :deb_build_host,
                      :debversion,
                      :debug,
                      :default_cow,
                      :default_mock,
                      :description,
                      :distribution_server,
                      :dmg_path,
                      :email,
                      :files,
                      :final_mocks,
                      :freight_conf,
                      :gem_default_executables,
                      :gem_dependencies,
                      :gem_description,
                      :gem_devel_dependencies,
                      :gem_excludes,
                      :gem_executables,
                      :gem_files,
                      :gem_forge_project,
                      :gem_name,
                      :gem_platform_dependencies,
                      :gem_rdoc_options,
                      :gem_require_path,
                      :gem_runtime_dependencies,
                      :gem_summary,
                      :gem_test_files,
                      :gemversion,
                      :gpg_key,
                      :gpg_name,
                      :homepage,
                      :ips_build_host,
                      :ips_host,
                      :ips_inter_cert,
                      :ips_package_host,
                      :ips_path,
                      :ips_repo,
                      :ips_store,
                      :ipsversion,
                      :jenkins_build_host,
                      :jenkins_packaging_job,
                      :jenkins_repo_path,
                      :metrics,
                      :metrics_url,
                      :name,
                      :notify,
                      :project,
                      :origversion,
                      :osx_build_host,
                      :packager,
                      :packaging_repo,
                      :packaging_url,
                      :pbuild_conf,
                      :pe_name,
                      :pe_version,
                      :pg_major_version,
                      :pre_tar_task,
                      :privatekey_pem,
                      :random_mockroot,
                      :rc_mocks,
                      :release,
                      :rpm_build_host,
                      :rpmrelease,
                      :rpmversion,
                      :ref,
                      :sign_tar,
                      :summary,
                      :tar_excludes,
                      :tar_host,
                      :tarball_path,
                      :task,
                      :team,
                      :templates,
                      :update_version_file,
                      :version,
                      :version_file,
                      :version_strategy,
                      :yum_host,
                      :yum_repo_path]

    @@build_params.each do |v|
      attr_accessor v
    end

    def initialize
      @task = { :task => $*[0], :args => $*[1..-1] }
      @ref = git_sha_or_tag
    end

    ##
    # Take a hash of parameters, and iterate over them,
    # setting each build param to the corresponding hash key,value.
    #
    def set_params_from_hash(data = {})
      data.each do |param, value|
        if @@build_params.include?(param.to_sym)
          self.instance_variable_set("@#{param}", value)
        else
          warn "Warning - No build data parameter found for '#{param}'. Perhaps you have an erroneous entry in your yaml file?"
        end
      end
    end

    ##
    # Load build parameters from a yaml file. Uses #data_from_yaml in
    # 00_utils.rake
    #
    def set_params_from_file(file)
      build_data = data_from_yaml(file)
      set_params_from_hash(build_data)
    end

    ##
    # Return a hash of all build parameters and their values, nil if unassigned.
    #
    def params
      data = {}
      @@build_params.each do |param|
        data.store(param, self.instance_variable_get("@#{param}"))
      end
      data
    end

    ##
    # Write all build parameters to a yaml file in a temporary location. Print
    # the path to the file and return it as a string. Accept an argument for
    # the write target directory. The name of the params file is the current
    # git commit sha or tag.
    #
    def params_to_yaml(output_dir=nil)
      dir = output_dir.nil? ? get_temp : output_dir
      File.writable?(dir) or fail "#{dir} does not exist or is not writable, skipping build params write. Exiting.."
      params_file = File.join(dir, "#{self.ref}.yaml")
      File.open(params_file, 'w') do |f|
        f.puts params.to_yaml
      end
      puts params_file
      params_file
    end

    ##
    # Print the names and values of all the params known to the build object
    #
    def print_params
      params.each { |k,v| puts "#{k}: #{v}" }
    end
  end
end

# Perform a build exclusively from a build params file. Requires that the build
# params file include a setting for task, which is an array of the arguments
# given to rake originally, including, first, the task name. The params file is
# always loaded when passed, so these variables are accessible immediately.
namespace :pl do
  desc "Build from a build params file"
  task :build_from_params do
    check_var('PARAMS_FILE', ENV['PARAMS_FILE'])
    git_co(@build.ref)
    Rake::Task[@build.task[:task]].invoke(@build.task[:args])
  end
end
