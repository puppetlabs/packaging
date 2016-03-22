# Title:        Rake task to build Apple packages for #{@project}.
# Author:       Gary Larizza
# Date:         05/18/2012
# Description:  This task will create a DMG-encapsulated package that will
#               install a package on OS X systems. This happens by building
#               a directory tree of files that will then be fed to the
#               packagemaker binary (can be installed by installing the
#               XCode Tools) which will create the .pkg file.
#

# Path to Binaries (Constants)
CP            = '/bin/cp'
INSTALL       = '/usr/bin/install'
DITTO         = '/usr/bin/ditto'
PKGBUILD      = '/usr/bin/pkgbuild'

# Setup task to populate all the variables
task :setup do
  # Read the Apple file-mappings
  begin
    @source_files        = Pkg::Util::Serialization.load_yaml('ext/osx/file_mapping.yaml')
  rescue
    fail "Could not load Apple file mappings from 'ext/osx/file_mapping.yaml'"
  end
  @package_name          = Pkg::Config.project
  @title                 = "#{Pkg::Config.project}-#{Pkg::Config.version}"
  @reverse_domain        = "com.#{Pkg::Config.packager}.#{@package_name}"
  @package_major_version = Pkg::Config.version.split('.')[0]
  @package_minor_version = Pkg::Config.version.split('.')[1] +
                           Pkg::Config.version.split('.')[2].split('-')[0].split('rc')[0]
  @pm_restart            = 'None'
  @build_date            = Time.new.strftime("%Y-%m-%dT%H:%M:%SZ")
  @apple_bindir          = File.join('/', @source_files['directories']['bin']['path'])
  @apple_sbindir         = '/usr/sbin'
  @apple_libdir          = File.join('/', @source_files['directories']['lib']['path'])
  @apple_old_libdir      = '/usr/lib/ruby/site_ruby/1.8'
  @apple_docdir          = '/usr/share/doc'
end

# method:       make_directory_tree
# description:  This method sets up the directory structure that packagemaker
#               needs to build a package. A prototype.plist file (holding
#               package-specific options) is built from an ERB template located
#               in the ext/osx directory.
def make_directory_tree
  project_tmp    = "#{Pkg::Util::File.mktemp}/#{@package_name}"
  @scratch       = "#{project_tmp}/#{@title}"
  @working_tree  = {
     'scripts'   => "#{@scratch}/scripts",
     'resources' => "#{@scratch}/resources",
     'working'   => "#{@scratch}/root",
     'payload'   => "#{@scratch}/payload",
  }
  puts "Cleaning Tree: #{project_tmp}"
  rm_rf(project_tmp)
  @working_tree.each do |key, val|
    mkdir_p(val)
  end

  if File.exists?('ext/osx/postflight.erb')
    Pkg::Util::File.erb_file 'ext/osx/postflight.erb', "#{@working_tree["scripts"]}/postinstall", false, :binding => binding
  end

  if File.exists?('ext/osx/preflight.erb')
    Pkg::Util::File.erb_file 'ext/osx/preflight.erb', "#{@working_tree["scripts"]}/preinstall", false, :binding => binding
  end

  if File.exists?('ext/osx/prototype.plist.erb')
    Pkg::Util::File.erb_file 'ext/osx/prototype.plist.erb', "#{@scratch}/prototype.plist", false, :binding => binding
  end

  if File.exists?('ext/packaging/static_artifacts/PackageInfo.plist')
    cp 'ext/packaging/static_artifacts/PackageInfo.plist', "#{@scratch}/PackageInfo.plist"
  end

end

# method:        build_dmg
# description:   This method builds a package from the directory structure in
#                /tmp/#{@project} and puts it in the
#                /tmp/#{@project}/#{@project}-#{version}/payload directory. A DMG is
#                created, using hdiutil, based on the contents of the
#                /tmp/#{@project}/#{@project}-#{version}/payload directory. The resultant
#                DMG is placed in the pkg/apple directory.
#
def build_dmg
  # Local Variables
  dmg_format_code   = 'UDZO'
  zlib_level        = '9'
  dmg_format_option = "-imagekey zlib-level=#{zlib_level}"
  dmg_format        = "#{dmg_format_code} #{dmg_format_option}"
  dmg_file          = "#{@title}.dmg"
  package_file      = "#{@title}.pkg"

  # Build .pkg file
  system("sudo #{PKGBUILD} --root #{@working_tree['working']} \
    --scripts #{@working_tree['scripts']} \
    --identifier #{@reverse_domain} \
    --version #{Pkg::Config.version} \
    --install-location / \
    --ownership preserve \
    --info #{@scratch}/PackageInfo.plist \
    #{@working_tree['payload']}/#{package_file}")

  # Build .dmg file
  system("sudo hdiutil create -volname #{@title} \
    -srcfolder #{@working_tree['payload']} \
    -uid 99 \
    -gid 99 \
    -ov \
    -format #{dmg_format} \
    #{dmg_file}")

  if File.directory?("#{pwd}/pkg/apple")
    sh "sudo mv #{pwd}/#{dmg_file} #{pwd}/pkg/apple/#{dmg_file}"
    puts "moved:   #{dmg_file} has been moved to #{pwd}/pkg/apple/#{dmg_file}"
  else
    mkdir_p("#{pwd}/pkg/apple")
    sh "sudo mv #{pwd}/#{dmg_file} #{pwd}/pkg/apple/#{dmg_file}"
    puts "moved:   #{dmg_file} has been moved to #{pwd}/pkg/apple/#{dmg_file}"
  end
end

# method:        pack_source
# description:   This method copies the #{@project} source into a directory
#                structure in /tmp/#{@project}/#{@project}-#{version}/root mirroring the
#                structure on the target system for which the package will be
#                installed. Anything installed into /tmp/#{@project}/root will be
#                installed as the package's payload.
#
def pack_source
  work          = "#{@working_tree['working']}"
  source = pwd

  # Make all necessary directories
  @source_files.each_value do |files|
    files.each_value do |params|
      mkdir_p "#{work}/#{params['path']}"
    end
  end

  # Install directory contents into place
  unless @source_files['directories'].nil?
    @source_files['directories'].each do |dir, params|
      unless FileList["#{source}/#{dir}/*"].empty?
        cmd = "#{DITTO} #{source}/#{dir}/ #{work}/#{params['path']}"
        puts cmd
        system(cmd)
      end
    end
  end

  # Setup a preinstall script and replace variables in the files with
  # the correct paths.
  if File.exists?("#{@working_tree['scripts']}/preinstall")
    chmod(0755, "#{@working_tree['scripts']}/preinstall")
    sh "sudo chown root:wheel #{@working_tree['scripts']}/preinstall"
  end

  # Setup a postinstall from from the erb created earlier
  if File.exists?("#{@working_tree['scripts']}/postinstall")
    chmod(0755, "#{@working_tree['scripts']}/postinstall")
    sh "sudo chown root:wheel #{@working_tree['scripts']}/postinstall"
  end

  # Do a run through first setting the specified permissions then
  # making sure 755 is set for all directories
  unless @source_files['directories'].nil?
    @source_files['directories'].each do |dir, params|
      owner = params['owner']
      group = params['group']
      perms = params['perms']
      path  = params['path']
      ##
      # Before setting our default permissions for all subdirectories/files of
      # each directory listed in directories, we have to get a list of the
      # directories. Otherwise, when we set the default perms (most likely
      # 0644) we'll lose traversal on subdirectories, and later when we want to
      # ensure they're 755 we won't be able to find them.
      #
      directories = []
      Dir["#{work}/#{path}/**/*"].each do |file|
        directories << file if File.directory?(file)
      end

      ##
      # Here we're setting the default permissions for all files as described
      # in file_mapping.yaml. Since we have a listing of directories, it
      # doesn't matter if we remove executable permission on directories, we'll
      # reset it later.
      #
      sh "sudo chmod -R #{perms} #{work}/#{path}"

      ##
      # We know at least one directory, the one listed in file_mapping.yaml, so
      # we set it executable.
      #
      sh "sudo chmod 0755 #{work}/#{path}"

      ##
      # Now that default perms are set, we go in and reset executable perms on
      # directories
      #
      directories.each { |d| sh "sudo chmod 0755 #{d}" }

      ##
      # Finally we set the owner/group as described in file_mapping.yaml
      #
      sh "sudo chown -R #{owner}:#{group} #{work}/#{path}"
    end
  end

  # Install any files
  unless @source_files['files'].nil?
    @source_files['files'].each do |file, params|
      owner = params['owner']
      group = params['group']
      perms = params['perms']
      dest  = params['path']
      # Allow for regexs like [A-Z]*
      FileList[file].each do |f|
        cmd = "sudo #{INSTALL} -o #{owner} -g #{group} -m #{perms} #{source}/#{f} #{work}/#{dest}"
        puts cmd
        system(cmd)
      end
    end
  end

  # Hackery here. Our packages were using /usr/bin/env ruby and installing to
  # system ruby loadpath, which breaks horribly in a multi-ruby (rbenv, etc)
  # environment. This goes into the workdir and looks for any files dropped in
  # bin, and "seds" the shebang to /usr/bin/ruby. I would love to be using a
  # ruby approach to this instead of shelling out to sed, but the problem is
  # we've already set ownership on these files, almost exclusively to root, and
  # thus we need to sudo out.
  if @source_files['directories'] and @source_files['directories']['bin']
    if bindir = @source_files['directories']['bin']['path']
      Dir[File.join(work, bindir, '*')].each do |binfile|
        sh "sudo /usr/bin/sed -E -i '' '1 s,^#![[:space:]]*/usr/bin/env[[:space:]]+ruby$,#!/usr/bin/ruby,' #{binfile}"
      end
    end
  end
end

namespace :package do
  desc "Task for building an Apple Package"
  task :apple => [:setup] do
    if Pkg::Config.build_dmg
      bench = Benchmark.realtime do
        # Test for pkgbuild binary
        fail "pkgbuild must be installed." unless \
          File.exists?(PKGBUILD)

        make_directory_tree
        pack_source
        build_dmg
      end
      puts "Finished building in: #{bench}"
    end
  end
end

# An alias task to simplify our remote logic in jenkins.rake
namespace :pl do
  task :dmg => "package:apple"
end
