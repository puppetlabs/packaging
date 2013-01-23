# tasks for sles building

# take a tarball and stage it in a temp dir with appropriate
# directories/files set up for building an rpm.
# return the directory

if @build_pe
  def prep_sles_dir
    temp = get_temp
    check_file("pkg/#{@project}-#{@version}.tar.gz")
    mkdir_pr temp, "#{temp}/SOURCES", "#{temp}/SPECS"
    if @sign_tar
      Rake::Task["pl:sign_tar"].invoke
      cp_p "pkg/#{@project}-#{@version}.tar.gz.asc", "#{temp}/SOURCES"
    end
    cp_p "pkg/#{@project}-#{@version}.tar.gz", "#{temp}/SOURCES"
    erb "ext/redhat/#{@project}.spec.erb", "#{temp}/SPECS/#{@project}.spec"
    temp
  end

  namespace :pe do
    # Temporary task to pull down pe dependencies until this is NFS-mounted
    task :retrieve_sles_deps => 'pl:load_extras' do
      rsync_from("#{@sles_repo_path}/#{@pe_version}/repos/sles-*", @sles_repo_host, "#{ENV['HOME']}/package_repos/")
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
    task :local_sles => ['package:tar', 'pl:fetch', 'pl:load_extras', 'pe:retrieve_sles_deps'] do
      check_tool('build')
      check_tool('linux32')
      check_tool('linux64')
      build_root        = get_temp
      work_dir          = prep_sles_dir
      build_source_dir  = "#{work_dir}/SOURCES"
      build_spec_dir    = "#{work_dir}/SPECS"
      build_spec        = "#{build_spec_dir}/#{@project}.spec"
      build_dest_dir    = "usr/src/packages"
      noarch            = FALSE
      build_dep_dir     = @sles_build_deps_dir
      build_os_dep_dir  = @sles_build_iso_dir
      built_arch        = ''
      @sles_arch_repos.each do |arch, deps_repo|
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
            rm_rf build_root
            rm_rf work_dir
          end
          # See 30_metrics.rake to see what this is doing
          add_metrics({ :dist => 'sles', :bench => bench }) if @benchmark
        else
          arches_to_copy_to = @sles_arch_repos.keys - [ built_arch ]
          arches_to_copy_to.each do |other_arch|
            %x{mkdir -p pkg/pe/rpm/sles-11-#{other_arch}}
            cp(FileList["pkg/pe/rpm/sles-11-#{built_arch}/*"], "pkg/pe/rpm/sles-11-#{other_arch}")
          end
        end
      end
      post_metrics if @benchmark
      cd 'pkg/pe/rpm' do
        if File.exist?('sles-11-i586')
          mkdir_p 'sles-11-i386'
          cp FileList["sles-11-i586/*"], 'sles-11-i386'
          rm_rf 'sles-11-i586'
        end
      end
      if @team == 'release'
        Rake::Task["pe:sign_rpms"].invoke
      end
    end
  end
end

