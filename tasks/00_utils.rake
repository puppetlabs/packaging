# Utility methods used by the various rake tasks

def check_tool(tool)
  return true if has_tool(tool)
  STDERR.puts "#{tool} tool not found...exiting"
  exit 1
end

def find_tool(tool)
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |root|
    location = File.join(root, tool)
    return location if FileTest.executable? location
  end
  return nil
end
alias :has_tool :find_tool

def check_file(file)
  unless File.exist?(file)
    STDERR.puts "#{file} file not found...exiting"
    exit 2
  end
end

def check_var(varname,var=nil)
  if var.nil?
    STDERR.puts "Requires #{varname} be set...exiting"
    exit 3
  end
end

def check_host(host)
  unless host == %x{hostname}.chomp!
    STDERR.puts "Requires host to be #{host}...exiting"
    exit 5
  end
end

def erb(erbfile,  outfile)
  template         = File.read(erbfile)
  message          = ERB.new(template, nil, "-")
  message.filename = erbfile
  output           = message.result(binding)
  File.open(outfile, 'w') { |f| f.write output }
  puts "Generated: #{outfile}"
end

def cp_pr(src, dest, options={})
  mandatory = {:preserve => true}
  cp_r(src, dest, options.merge(mandatory))
end

def cp_p(src, dest, options={})
  mandatory = {:preserve => true}
  cp(src, dest, options.merge(mandatory))
end

def mv_f(src, dest, options={})
  force = {:force => true}
  mv(src, dest, options.merge(mandatory))
end

def git_co(dist)
  %x{git reset --hard ; git checkout #{dist}}
  unless $?.success?
    STDERR.puts 'Could not checkout #{dist} git branch to build package from...exiting'
    exit 1
  end
end

def get_temp
  temp = `mktemp -d -t tmpXXXXXX`.strip
end

def remote_ssh_cmd target, command
  check_tool('ssh')
  puts "Executing '#{command}' on #{target}"
  sh "ssh -t #{target} '#{command.gsub("'", "'\\\\''")}'"
end

def rsync_to *args
  check_tool('rsync')
  flags = "-Havxl -O --no-perms --no-owner --no-group"
  source  = args[0]
  target  = args[1]
  dest    = args[2]
  puts "rsyncing #{source} to #{target}"
  sh "rsync #{flags} #{source} #{target}:#{dest}"
end

def rsync_from *args
  check_tool('rsync')
  flags = "-Havxl -O --no-perms --no-owner --no-group"
  source  = args[0]
  target  = args[1]
  dest    = args[2]
  puts "rsyncing #{source} from #{target} to #{dest}"
  sh "rsync #{flags} #{target}:#{source} #{dest}"
end

def scp_file_from(host,path,file)
  %x{scp #{host}:#{path}/#{file} #{@tempdir}/#{file}}
end

def scp_file_to(host,path,file)
  %x{scp #{@tempdir}/#{file} #{host}:#{path}}
end

def timestamp
  Time.now.strftime("%Y-%m-%d %H:%M:%S")
end

# Return information about the current tree, using `git describe`, ready for
# further processing.
#
# Returns an array of one to four elements, being:
# * version (three dot-joined numbers, leading `v` stripped)
# * the string 'rcX' (if the last tag was an rc release, where X is the rc number)
# * commits (string containing integer, number of commits since that version was tagged)
# * dirty (string 'dirty' if local changes exist in the repo)
def git_describe_version
  return nil unless is_git_repo and raw = run_git_describe_internal
  # reprocess that into a nice set of output data
  # The elements we select potentially change if this is an rc
  # For an rc with added commits our string will be something like '0.7.0-rc1-63-g51ccc51'
  # and our return will be [0.7.0, rc1, 63, <dirty>]
  # For a final with added commits, it will look like '0.7.0-63-g51ccc51'
  # and our return will be [0.7.0, 64, <dirty>]
  info = raw.chomp.sub(/^v/, '').split('-')
  if info[1].to_s.match('^[\d]+')
    version_string = info.values_at(0,1,3).compact
  else
    version_string = info.values_at(0,1,2,4).compact
  end
  version_string
end

# This is a stub to ease testing...
def run_git_describe_internal
  raw = %x{git describe --tags --dirty 2>/dev/null}
  $?.success? ? raw : nil
end

def get_dash_version
  if info = git_describe_version
    info.join('-')
  else
    get_pwd_version
  end
end

def uname_r
  %x{uname -r}.chomp
end

def get_ips_version
  if info = git_describe_version
    version, commits, dirty = info
    if commits.to_s.match('^rc[\d]+')
      commits = info[2]
      dirty   = info[3]
    end
    osrelease = uname_r
    "#{version},#{osrelease}-#{commits.to_i}#{dirty ? '-dirty' : ''}"
  else
    get_pwd_version
  end
end

def get_dot_version
  get_dash_version.gsub('-', '.')
end

def get_pwd_version
  %x{pwd}.strip.split('.')[-1]
end

def get_base_pkg_version
  dash = get_dash_version
  if dash.include?("rc")
    # Grab the rc number
    rc_num = dash.match(/rc(\d)+/)[1]
    ver = dash.sub(/-?rc[0-9]+/, "-0.1rc#{rc_num}").gsub(/(rc[0-9]+)-(\d+)?-?/, '\1.\2')
  else
    ver = dash.gsub('-','.') + "-1"
  end

  ver.split('-')
end

def get_debversion
  get_base_pkg_version.join('-') << "#{@packager}#{get_debrelease}"
end

def get_origversion
  @debversion.split('-')[0]
end

def get_rpmversion
  get_base_pkg_version[0]
end

def get_version_file_version
  # Match version files containing 'VERSION = "x.x.x"' and just x.x.x
  contents = IO.read(@version_file)
  if version_string = contents.match(/VERSION =.*/)
    version_string.to_s.split()[-1]
  else
    contents
  end
end

def get_debrelease
  ENV['RELEASE'] || '1'
end

def get_rpmrelease
  ENV['RELEASE'] || get_base_pkg_version[1]
end

def load_keychain
  unless @keychain_loaded
    kill_keychain
    start_keychain
    @keychain_loaded = TRUE
  end
end

def kill_keychain
  %x{keychain -k mine}
end

def start_keychain
  keychain = %x{/usr/bin/keychain -q --agents gpg --eval #{@gpg_key}}.chomp
  new_env = keychain.match(/(GPG_AGENT_INFO)=([^;]*)/)
  ENV[new_env[1]] = new_env[2]
end

def gpg_sign_file(file)
  gpg ||= find_tool('gpg')

  if gpg
    sh "#{gpg} --armor --detach-sign -u #{@gpg_key} #{file}"
  else
    STDERR.puts "No gpg available. Cannot sign #{file}. Exiting..."
    exit 1
  end
end

def mkdir_pr *args
  args.each do |arg|
    mkdir_p arg
  end
end

def set_cow_envs(cow)
  elements = cow.split('-')
  if elements.size != 3
    STDERR.puts "Expecting a cow name split on hyphens, e.g. 'base-squeeze-i386'"
    exit 1
  else
    dist = elements[1]
    arch = elements[2]
    if dist.nil? or arch.nil?
      STDERR.puts "Couldn't get the arg and dist from cow name. Expecting something like 'base-dist-arch'"
      exit 1
    end
    arch = arch.split('.')[0] if arch.include?('.')
  end

  ENV['DIST'] = dist
  ENV['ARCH'] = arch
end

def ln(target, name)
  FileUtils.ln(name, target, :force => true, :verbose => true)
end

def git_commit_file(file, message=nil)
  if has_tool('git') and File.exist?('.git')
    message ||= "changes"
    puts "Commiting changes:"
    puts
    diff = %x{git diff HEAD #{file}}
    puts diff
    %x{git commit #{file} -m "Commit #{message} in #{file}" &> /dev/null}
  end
end

def ship_gem(file)
  %x{gem push #{file}}
end

def ask_yes_or_no
  return boolean_value(ENV['ANSWER_OVERRIDE']) unless ENV['ANSWER_OVERRIDE'].nil?
  answer = STDIN.gets.downcase.chomp
  return TRUE if answer =~ /^y$|^yes$/
  return FALSE if answer =~ /^n$|^no$/
  puts "Nope, try something like yes or no or y or n, etc:"
  ask_yes_or_no
end

def handle_method_failure(method, args)
  STDERR.puts "There was an error running the method #{method} with the arguments:"
  args.each { |param, arg| STDERR.puts "\t#{param} => #{arg}\n" }
  STDERR.puts "The rake session is paused. Would you like to retry #{method} with these args and continue where you left off? [y,n]"
  if ask_yes_or_no
    send(method, args)
  else
    exit 1
  end
end

def invoke_task(task, args=nil)
  Rake::Task[task].reenable
  Rake::Task[task].invoke(args)
end

def confirm_ship(files)
  STDOUT.puts "The following files have been built and are ready to ship:"
  files.each { |file| STDOUT.puts "\t#{file}\n" unless File.directory?(file) }
  STDOUT.puts "Ship these files?? [y,n]"
  ask_yes_or_no
end

def boolean_value(var)
  return TRUE if (var == TRUE || ( var.is_a?(String) && ( var.downcase == 'true' || var.downcase =~ /^y$|^yes$/ )))
  FALSE
end

def git_tag(version)
  begin
    sh "git tag -s -u #{@gpg_key} -m '#{version}' #{version}"
  rescue Exception => e
    STDERR.puts e
    STDERR.puts "Unable to tag repo at #{version}"
    exit 1
  end
end

def rand_string
  rand.to_s.split('.')[1]
end

def git_bundle(treeish)
  temp = get_temp
  appendix = rand_string
  sh "git bundle create #{temp}/#{@name}-#{@version}-#{appendix} #{treeish} --tags"
  cd temp do
    sh "tar -czf #{@name}-#{@version}-#{appendix}.tar.gz #{@name}-#{@version}-#{appendix}"
    rm_rf "#{@name}-#{@version}-#{appendix}"
  end
  "#{temp}/#{@name}-#{@version}-#{appendix}.tar.gz"
end

# We take a tar argument for cases where `tar` isn't best, e.g. Solaris
def remote_bootstrap(host, treeish, tar_cmd=nil)
  unless tar = tar_cmd
    tar = 'tar'
  end
  tarball = git_bundle(treeish)
  tarball_name = File.basename(tarball).gsub('.tar.gz','')
  rsync_to(tarball, host, '/tmp')
  appendix = rand_string
  sh "ssh -t #{host} '#{tar} -zxvf /tmp/#{tarball_name}.tar.gz -C /tmp/ ; git clone --recursive /tmp/#{tarball_name} /tmp/#{@name}-#{appendix} ; cd /tmp/#{@name}-#{appendix} ; rake package:bootstrap'"
  "/tmp/#{@name}-#{appendix}"
end

def is_git_repo
  %x{git rev-parse --git-dir > /dev/null 2>&1}
  return $?.success?
end

def git_pull(remote, branch)
  sh "git pull #{remote} #{branch}"
end

def create_rpm_repo(dir)
  check_tool('createrepo')
  cd dir do
    sh "createrepo -d ."
  end
end

def update_rpm_repo(dir)
  check_tool('createrepo')
  cd dir do
    sh "createrepo -d --update ."
  end
end

def empty_dir?(dir)
  File.exist?(dir) and File.directory?(dir) and Dir["#{dir}/**/*"].empty?
end

def hostname
  require 'socket'
  host = Socket.gethostname
end
