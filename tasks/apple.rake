# Title:        Rake task to build Apple packages for #{@name}.
# Author:       Gary Larizza
# Date:         05/18/2012
# Description:  This task will create a DMG-encapsulated package that will
#               install a package on OS X systems. This happens by building
#               a directory tree of files that will then be fed to the
#               packagemaker binary (can be installed by installing the
#               XCode Tools) which will create the .pkg file.
#

# Path to Binaries (Constants)
TAR           = '/usr/bin/tar'
CP            = '/bin/cp'
INSTALL       = '/usr/bin/install'
DITTO         = '/usr/bin/ditto'
PACKAGEMAKER  = '/Developer/usr/bin/packagemaker'
SED           = '/usr/bin/sed'

# Setup task to populate all the variables
task :setup do
  # Read the Apple file-mappings
  begin
    @source_files        = YAML.load_file('ext/osx/file_mapping.yaml')
  rescue
    STDERR.puts "Could not load Apple file mappings from 'ext/osx/file_mapping.yaml'"
    exit 1
  end
  @package_name          = @name
  @title                 = "#{@name}-#{@version}"
  @reverse_domain        = "com.#{@packager}.#{@package_name}"
  @package_major_version = @version.split('.')[0]
  @package_minor_version = @version.split('.')[1] +
                           @version.split('.')[2].split('-')[0].split('rc')[0]
  @pm_restart            = 'None'
  @build_date            = Time.new.strftime("%Y-%m-%dT%H:%M:%SZ")
  @apple_bindir          = '/usr/bin'
  @apple_sbindir         = '/usr/sbin'
  @apple_libdir          = '/usr/lib/ruby/site_ruby/1.8'
  @apple_docdir          = '/usr/share/doc'
end

# method:       make_directory_tree
# description:  This method sets up the directory structure that packagemaker
#               needs to build a package. A prototype.plist file (holding
#               package-specific options) is built from an ERB template located
#               in the ext/osx directory.
def make_directory_tree
  project_tmp    = "#{get_temp}/#{@package_name}"
  @scratch       = "#{project_tmp}/#{@title}"
  @working_tree  = {
     'scripts'   => "#{@scratch}/scripts",
     'resources' => "#{@scratch}/resources",
     'working'   => "#{@scratch}/root",
     'payload'   => "#{@scratch}/payload",
  }
  puts "Cleaning Tree: #{project_tmp}"
  rm_rf(project_tmp)
  @working_tree.each do |key,val|
    mkdir_p(val)
  end

  if File.exists?('ext/osx/postflight.erb')
    erb 'ext/osx/postflight.erb', "#{@working_tree["scripts"]}/postflight"
  end

  if File.exists?('ext/osx/preflight.erb')
    erb 'ext/osx/preflight.erb', "#{@working_tree["scripts"]}/preflight"
  end

  if File.exists?('ext/osx/prototype.plist.erb')
    erb 'ext/osx/prototype.plist.erb', "#{@scratch}/prototype.plist"
  end

end

# method:        build_dmg
# description:   This method builds a package from the directory structure in
#                /tmp/#{@name} and puts it in the
#                /tmp/#{@name}/#{@name}-#{version}/payload directory. A DMG is
#                created, using hdiutil, based on the contents of the
#                /tmp/#{@name}/#{@name}-#{version}/payload directory. The resultant
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
  pm_extra_args     = '--verbose --no-recommend --no-relocate'
  package_target_os = '10.4'

  # Build .pkg file
  system("sudo #{PACKAGEMAKER} --root #{@working_tree['working']} \
    --id #{@reverse_domain} \
    --filter DS_Store \
    --target #{package_target_os} \
    --title #{@title} \
    --info #{@scratch}/prototype.plist \
    --scripts #{@working_tree['scripts']} \
    --resources #{@working_tree['resources']} \
    --version #{@version} \
    #{pm_extra_args} --out #{@working_tree['payload']}/#{package_file}")

  # Build .dmg file
  system("sudo hdiutil create -volname #{@title} \
    -srcfolder #{@working_tree['payload']} \
    -uid 99 \
    -gid 99 \
    -ov \
    -format #{dmg_format} \
    #{dmg_file}")

  if File.directory?("#{pwd}/pkg/apple")
    mv("#{pwd}/#{dmg_file}", "#{pwd}/pkg/apple/#{dmg_file}")
    puts "moved:   #{dmg_file} has been moved to #{pwd}/pkg/apple/#{dmg_file}"
  else
    mkdir_p("#{pwd}/pkg/apple")
    mv(dmg_file, "#{pwd}/pkg/apple/#{dmg_file}")
    puts "moved:   #{dmg_file} has been moved to #{pwd}/pkg/apple/#{dmg_file}"
  end
end

# method:        pack_source
# description:   This method copies the #{@name} source into a directory
#                structure in /tmp/#{@name}/#{@name}-#{version}/root mirroring the
#                structure on the target system for which the package will be
#                installed. Anything installed into /tmp/#{@name}/root will be
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

  # Setup a preflight script and replace variables in the files with
  # the correct paths.
  if File.exists?("#{@working_tree['scripts']}/preflight")
    chown('root', 'wheel', "#{@working_tree['scripts']}/preflight")
    chmod(0644, "#{@working_tree['scripts']}/preflight")
  end

  # Setup a postflight from from the erb created earlier
  if File.exists?("#{@working_tree['scripts']}/postflight")
    chown('root', 'wheel', "#{@working_tree['scripts']}/postflight")
    chmod(0755, "#{@working_tree['scripts']}/postflight")
  end

  # Do a run through first setting the specified permissions then
  # making sure 755 is set for all directories
  unless @source_files['directories'].nil?
    @source_files['directories'].each do |dir, params|
      owner = params['owner']
      group = params['group']
      perms = params['perms']
      path  = params['path']
      chmod_R(Integer(perms), "#{work}/#{path}")
      chown_R(owner, group, "#{work}/#{path}")
      chmod(0755, "#{work}/#{path}")
      Dir["#{work}/#{path}/**/*"].each do |file|
        chmod(0755, file) if File.directory?(file)
      end
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
      FileList[file].each do |file|
        cmd = "#{INSTALL} -o #{owner} -g #{group} -m #{perms} #{source}/#{file} #{work}/#{dest}"
        puts cmd
        system(cmd)
      end
    end
  end
end

if @build_dmg
  namespace :package do
    desc "Task for building an Apple Package"
    task :apple => [:setup] do
      bench = Benchmark.realtime do
        # Test for Root and Packagemaker binary
        raise "Please run rake as root to build Apple Packages" unless Process.uid == 0
        raise "Packagemaker must be installed. Please install XCode Tools" unless \
          File.exists?('/Developer/usr/bin/packagemaker')

        make_directory_tree
        pack_source
        build_dmg
        chmod_R(0775, "#{pwd}/pkg")
      end
      if @benchmark
        add_metrics({ :dist => 'osx', :bench => bench })
        post_metrics
      end
    end
  end
end

