# tasks for sles building

# take a tarball and stage it in a temp dir with appropriate
# directories/files set up for building an rpm.
# return the directory

if @build.build_pe
  def prep_sles_dir
    temp = get_temp
    check_file("pkg/#{@build.project}-#{@build.version}.tar.gz")
    mkdir_pr temp, "#{temp}/SOURCES", "#{temp}/SPECS"
    if @build.sign_tar
      Rake::Task["pl:sign_tar"].invoke
      cp_p "pkg/#{@build.project}-#{@build.version}.tar.gz.asc", "#{temp}/SOURCES"
    end
    cp_p "pkg/#{@build.project}-#{@build.version}.tar.gz", "#{temp}/SOURCES"
    erb "ext/redhat/#{@build.project}.spec.erb", "#{temp}/SPECS/#{@build.project}.spec"
    temp
  end

  namespace :pe do
    # Temporary task to pull down pe dependencies until this is NFS-mounted
    task :retrieve_sles_deps => 'pl:fetch' do
      rm_rf FileList["#{ENV['HOME']}/package_repos/*"]
      rsync_from("#{@build.sles_repo_path}/#{@build.pe_version}/repos/sles-*", @build.sles_repo_host, "#{ENV['HOME']}/package_repos/")
      FileList["#{ENV['HOME']}/package_repos/*"].each do |f|
        update_rpm_repo(f) if File.directory?(f)
      end
      cd "#{ENV['HOME']}/package_repos" do
        unless File.symlink?('sles-11-i586')
          if File.exist?('sles-11-i586')
            rm_rf 'sles-11-i586'
          end
          File.symlink('sles-11-i386', 'sles-11-i586')
        end
      end
    end

    desc "Build a sles rpm from this repo"
    manageable_task :local_sles => ['package:tar', 'pl:fetch', 'pe:retrieve_sles_deps'] do
      check_tool('build')
      check_tool('linux32')
      check_tool('linux64')
      build_dest_dir    = "usr/src/packages"
      noarch            = FALSE
      built_arch        = ''
      @build.sles_arch_repos.each do |arch, deps_repo|
        build_root        = get_temp
        work_dir          = prep_sles_dir
        build_source_dir  = "#{work_dir}/SOURCES"
        build_spec_dir    = "#{work_dir}/SPECS"
        build_spec        = "#{build_spec_dir}/#{@build.project}.spec"
        if noarch == FALSE
          bench = Benchmark.realtime do
            linux_cmd = arch == 'i586' ? 'linux32' : 'linux64'
            sh "yes | sudo #{linux_cmd} build \
              --rpms        #{deps_repo}:#{ENV['HOME']}/package_repos/sles-11-#{arch} \
              --root        #{build_root}/#{arch}                                     \
              --rsync-src   #{build_source_dir}                                       \
              --rsync-dest  /usr/src/packages/SOURCES                                 \
              --no-checks   #{build_spec}                                             \
              --arch        #{arch} || true"
            rpms = FileList["#{build_root}/#{arch}/#{build_dest_dir}/RPMS/**/*.rpm"]
            srpms = FileList["#{build_root}/#{arch}/#{build_dest_dir}/SRPMS/**/*.rpm"]
            if rpms.empty?
              STDERR.puts "No RPMS were built. Perhaps an error occurred?"
              exit 1
            end
            built_arch = arch
            %x{mkdir -p pkg/pe/rpm/sles-11-{srpms,#{arch}}}
            cp(rpms, "pkg/pe/rpm/sles-11-#{arch}")
            cp(srpms, "pkg/pe/rpm/sles-11-srpms")
            noarch = rpms.exclude(/noarch/).empty?
          end
          # See 30_metrics.rake to see what this is doing
          add_metrics({ :dist => 'sles', :bench => bench }) if @build.benchmark
        else
          arches_to_copy_to = @build.sles_arch_repos.keys - [ built_arch ]
          arches_to_copy_to.each do |other_arch|
            %x{mkdir -p pkg/pe/rpm/sles-11-#{other_arch}}
            cp(FileList["pkg/pe/rpm/sles-11-#{built_arch}/*"], "pkg/pe/rpm/sles-11-#{other_arch}")
          end
        end
        rm_rf build_root
        rm_rf work_dir
      end
      post_metrics if @build.benchmark
      cd 'pkg/pe/rpm' do
        if File.exist?('sles-11-i586')
          mkdir_p 'sles-11-i386'
          cp FileList["sles-11-i586/*"], 'sles-11-i386'
          rm_rf 'sles-11-i586'
        end
      end
      if @build.team == 'release'
        Rake::Task["pe:sign_rpms"].invoke
      end
    end
  end
end

