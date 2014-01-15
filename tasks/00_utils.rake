# Utility methods used by the various rake tasks

def check_tool(tool)
  return true if has_tool(tool)
  fail "#{tool} tool not found...exiting"
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
  File.exist?(file) or fail "#{file} file not found!"
end

def check_var(varname,var=nil)
  var.nil? and fail "Requires #{varname} be set!"
end

def check_host(host)
  host == %x{hostname}.chomp! or fail "Requires host to be #{host}!"
end

def erb_string(erbfile)
  template  = File.read(erbfile)
  message   = ERB.new(template, nil, "-")
  message.result(binding)
end

def erb(erbfile,  outfile)
  output           = erb_string(erbfile)
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
  mandatory = {:force => true}
  mv(src, dest, options.merge(mandatory))
end

def git_co(ref)
  %x{git reset --hard ; git checkout #{ref}}
  $?.success? or fail "Could not checkout #{ref} git branch to build package from...exiting"
end

def git_describe
  %x{git describe}.strip
end

# return the sha of HEAD on the current branch
def git_sha
  %x{git rev-parse HEAD}.strip
end

# Return the ref type of HEAD on the current branch
def git_ref_type
  %x{git cat-file -t #{git_describe}}.strip
end

# If HEAD is a tag, return the tag. Otherwise return the sha of HEAD.
def git_sha_or_tag
  if git_ref_type == "tag"
    git_describe
  else
    git_sha
  end
end

def get_temp
  `mktemp -d -t pkgXXXXXX`.strip
end

def remote_ssh_cmd target, command
  check_tool('ssh')
  puts "Executing '#{command}' on #{target}"
  sh "ssh -t #{target} '#{command.gsub("'", "'\\\\''")}'"
end

def rsync_to *args
  check_tool('rsync')
  flags = "-rHlv -O --no-perms --no-owner --no-group --ignore-existing"
  source  = args[0]
  target  = args[1]
  dest    = args[2]
  puts "rsyncing #{source} to #{target}"
  sh "rsync #{flags} #{source} #{target}:#{dest}"
end

def rsync_from *args
  check_tool('rsync')
  flags = "-rHlv -O --no-perms --no-owner --no-group"
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

def timestamp(separator=nil)
  if s = separator
    format = "%Y#{s}%m#{s}%d#{s}%H#{s}%M#{s}%S"
  else
    format = "%Y-%m-%d %H:%M:%S"
  end
  Time.now.strftime(format)
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
    rc_num = dash.match(/rc(\d+)/)[1]
    ver = dash.sub(/-?rc[0-9]+/, "-0.#{@build.release}rc#{rc_num}").gsub(/(rc[0-9]+)-(\d+)?-?/, '\1.\2')
  else
    ver = dash.gsub('-','.') + "-#{@build.release}"
  end

  ver.split('-')
end

def get_debversion
  get_base_pkg_version.join('-') << "#{@build.packager}1"
end

def get_origversion
  @build.debversion.split('-')[0]
end

def get_rpmversion
  get_base_pkg_version[0]
end

def get_release
  ENV['RELEASE'] || '1'
end

def get_rpmrelease
  get_base_pkg_version[1]
end

def load_keychain
  unless @keychain_loaded
    unless ENV['RPM_GPG_AGENT']
      kill_keychain
      start_keychain
    end
    @keychain_loaded = TRUE
  end
end

def source_dirty?
  git_describe_version.include?('dirty')
end

def fail_on_dirty_source
  if source_dirty?
    fail "
The source tree is dirty, e.g. there are uncommited changes. Please
commit/discard changes and try again."
  end
end

def kill_keychain
  %x{keychain -k mine}
end

def start_keychain
  keychain = %x{/usr/bin/keychain -q --agents gpg --eval #{@build.gpg_key}}.chomp
  new_env = keychain.match(/(GPG_AGENT_INFO)=([^;]*)/)
  ENV[new_env[1]] = new_env[2]
end

def gpg_sign_file(file)
  gpg ||= find_tool('gpg')

  if gpg
    use_tty = "--no-tty --use-agent" if ENV['RPM_GPG_AGENT']
    sh "#{gpg} #{use_tty} --armor --detach-sign -u #{@build.gpg_key} #{file}"
  else
    fail "No gpg available. Cannot sign #{file}."
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
    fail "Expecting a cow name split on hyphens, e.g. 'base-squeeze-i386'"
  else
    dist = elements[1]
    arch = elements[2]
    if dist.nil? or arch.nil?
      fail "Couldn't get the arg and dist from cow name. Expecting something like 'base-dist-arch'"
    end
    arch = arch.split('.')[0] if arch.include?('.')
  end
  if @build.build_pe
    ENV['PE_VER'] = @build.pe_version
  end
  ENV['DIST'] = dist
  ENV['ARCH'] = arch
  if dist =~ /cumulus/
    ENV['NETWORK_OS'] = 'cumulus'
  end
end

def ln(target, name)
  FileUtils.ln(name, target, :force => true, :verbose => true)
end

def ln_sfT(src, dest)
  sh "ln -sfT #{src} #{dest}"
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
  check_file("#{ENV['HOME']}/.gem/credentials")
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
  sh "git tag -s -u #{@build.gpg_key} -m '#{version}' #{version}"
  $?.success or fail "Unable to tag repo at #{version}"
end

def rand_string
  rand.to_s.split('.')[1]
end

def git_bundle(treeish, appendix=nil, output_dir=nil)
  temp = output_dir || get_temp
  appendix ||= rand_string
  sh "git bundle create #{temp}/#{@build.project}-#{@build.version}-#{appendix} #{treeish} --tags"
  cd temp do
    sh "tar -czf #{@build.project}-#{@build.version}-#{appendix}.tar.gz #{@build.project}-#{@build.version}-#{appendix}"
    rm_rf "#{@build.project}-#{@build.version}-#{appendix}"
  end
  "#{temp}/#{@build.project}-#{@build.version}-#{appendix}.tar.gz"
end

# We take a tar argument for cases where `tar` isn't best, e.g. Solaris.  We
# also take an optional argument of the tarball containing the git bundle to
# use.
def remote_bootstrap(host, treeish, tar_cmd=nil, tarball=nil)
  unless tar = tar_cmd
    tar = 'tar'
  end
  tarball ||= git_bundle(treeish)
  tarball_name = File.basename(tarball).gsub('.tar.gz','')
  rsync_to(tarball, host, '/tmp')
  appendix = rand_string
  sh "ssh -t #{host} '#{tar} -zxvf /tmp/#{tarball_name}.tar.gz -C /tmp/ ; git clone --recursive /tmp/#{tarball_name} /tmp/#{@build.project}-#{appendix} ; cd /tmp/#{@build.project}-#{appendix} ; rake package:bootstrap'"
  "/tmp/#{@build.project}-#{appendix}"
end

# Given a BuildInstance object and a host, send its params to the host. Return
# the remote path to the params.
def remote_buildparams(host, build)
  params_file = build.params_to_yaml
  params_file_name = File.basename(params_file)
  params_dir = rand_string
  rsync_to(params_file, host, "/tmp/#{params_dir}/")
  "/tmp/#{params_dir}/#{params_file_name}"
end

def is_git_repo
  %x{git rev-parse --git-dir > /dev/null 2>&1}
  return $?.success?
end

def git_pull(remote, branch)
  sh "git pull #{remote} #{branch}"
end

def update_rpm_repo(dir)
  check_tool('createrepo')
  cd dir do
    sh "createrepo --checksum=sha --database --update ."
  end
end
alias :create_rpm_repo :update_rpm_repo

def empty_dir?(dir)
  File.exist?(dir) and File.directory?(dir) and Dir["#{dir}/**/*"].empty?
end

def hostname
  require 'socket'
  Socket.gethostname
end

# Loop a block up to the number of attempts given, exiting when we receive success
# or max attempts is reached. Raise an exception unless we've succeeded.
def retry_on_fail(args, &blk)
  success = FALSE
  if args[:times].respond_to?(:times) and block_given?
    args[:times].times do |i|
      begin
        blk.call
        success = TRUE
        break
      rescue
        puts "An error was encountered evaluating block. Retrying.."
      end
    end
  else
    fail "retry_on_fail requires and arg (:times => x) where x is an Integer/Fixnum, and a block to execute"
  end
  fail "Block failed maximum of #{args[:times]} tries. Exiting.." unless success
end

def deprecate(old_cmd, new_cmd=nil)
  msg = "!! #{old_cmd} is deprecated."
  if new_cmd
    msg << " Please use #{new_cmd} instead."
  end
  STDOUT.puts
  STDOUT.puts(msg)
  STDOUT.puts
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
  ret = nil
  case @build.version_strategy
    when "rc_final"
      ret = is_rc?
    when "odd_even"
      ret = is_odd?
    when nil
      ret = is_rc?
  end
  return (! ret)
end

# the rc_final strategy (default)
# Assumes version strings in the formats:
# final:
# '0.7.0'
# '0.7.0-63'
# '0.7.0-63-dirty'
# development:
# '0.7.0rc1 (we don't actually use this format anymore, but once did)
# '0.7.0-rc1'
# '0.7.0-rc1-63'
# '0.7.0-rc1-63-dirty'
def is_rc?
  return TRUE if get_dash_version =~ /^\d+\.\d+\.\d+-*rc\d+/
  return FALSE
end

# the odd_even strategy (mcollective)
# final:
# '0.8.0'
# '1.8.0-63'
# '0.8.1-63-dirty'
# development:
# '0.7.0'
# '1.7.0-63'
# '0.7.1-63-dirty'
def is_odd?
  return TRUE if get_dash_version.match(/^\d+\.(\d+)\.\d+/)[1].to_i.odd?
  return FALSE
end

# Utility method to return the dist method if this is a redhat box. We use this
# in rpm packaging to define a dist macro, and we use it in the pl:fetch task
# to disable ssl checking for redhat 5 because it has a certs bundle so old by
# default that it's useless for our purposes.
def el_version
  if File.exists?('/etc/fedora-release')
    nil
  elsif File.exists?('/etc/redhat-release')
    return %x{rpm -q --qf \"%{VERSION}\" $(rpm -q --whatprovides /etc/redhat-release )}
  end
end

# Given the path to a yaml file, load the yaml file into an object and return
# the object.
def data_from_yaml(file)
  file = File.expand_path(file)
  begin
    input_data = YAML.load_file(file) || {}
  rescue => e
    STDERR.puts "There was an error loading data from #{file}."
    fail e.backtrace.join("\n")
  end
  input_data
end

# This is fairly absurd. We're implementing curl by shelling out. What do I
# wish we were doing? Using a sweet ruby wrapper around curl, such as Curb or
# Curb-fu. However, because we're using clean build systems and trying to
# make this portable with minimal system requirements, we can't very well
# depend on libraries that aren't in the ruby standard libaries. We could
# also do this using Net::HTTP but that set of libraries is a rabbit hole to
# go down when what we're trying to accomplish is posting multi-part form
# data that includes file uploads to jenkins. It gets hairy fairly quickly,
# but, as they say, pull requests accepted.
#
# This method takes two arguments
# 1) String - the URL to post to
# 2) Array  - Ordered array of name=VALUE curl form parameters
def curl_form_data(uri, form_data=[], options={})
  curl = find_tool("curl") or fail "Couldn't find curl. Curl is required for posting jenkins to trigger a build. Please install curl and try again."
  #
  # Begin constructing the post string.
  # First, assemble the form_data arguments
  #
  post_string = "-i "
  form_data.each do |param|
    post_string << "#{param} "
  end

  # Add the uri
  post_string << "#{uri}"

  # If this is quiet, we're going to silence all output
  if options[:quiet]
    post_string << " >/dev/null 2>&1"
  end

  %x{#{curl} #{post_string}}
  return $?.success?
end

def random_string length
  rand(36**length).to_s(36)
end

# Use the curl to create a jenkins job from a valid XML
# configuration file.
# Returns the URL to the job
def create_jenkins_job(name, xml_file)
  create_url = "http://#{@build.jenkins_build_host}/createItem?name=#{name}"
  form_args = ["-H", '"Content-Type: application/xml"', "--data-binary", "@#{xml_file}"]
  curl_form_data(create_url, form_args)
  "http://#{@build.jenkins_build_host}/job/#{name}"
end

# Use the curl to check of a named job is defined on the jenkins server.  We
# curl the config file rather than just checking if the job exists by curling
# the job url and passing --head because jenkins will mistakenly return 200 OK
# if you issue multiple very fast requests just requesting the header.
def jenkins_job_exists?(name)
  job_url = "http://#{@build.jenkins_build_host}/job/#{name}/config.xml"
  form_args = ["--silent", "--fail"]
  curl_form_data(job_url, form_args, :quiet => true)
end

def require_library_or_fail(library)
  begin
    require library
  rescue LoadError
    fail "Could not load #{library}. #{library} is required by the packaging repo for this task"
  end
end

# Use the provided URL string to print important information with
# ASCII emphasis
def print_url_info(url_string)
puts "\n////////////////////////////////////////////////////////////////////////////////\n\n
  Build submitted. To view your build progress, go to\n#{url_string}\n\n
////////////////////////////////////////////////////////////////////////////////\n\n"
end

def escape_html(uri)
  require 'cgi'
  CGI.escapeHTML(uri)
end

# Add a parameter to a given uri. If we were sane we'd use
# encode_www_form(params) of URI, but because we're not, because that will http
# encode it, which isn't what we want since we're require the encoding provided
# by escapeHTML of CGI, since this is being transfered in the xml of a jenkins
# job via curl and DEAR JEEBUS WHAT HAVE WE DONE.
def add_param_to_uri(uri, param)
  require 'uri'
  uri = URI.parse(uri)
  uri.query = [uri.query, param].compact.join('&')
  uri.to_s
end

# Remotely set the immutable bit on a list of files
#
def remote_set_immutable(host, files)
  remote_ssh_cmd(host, "sudo chattr +i #{files.join(" ")}")
end

# ex combines the behavior of `%x{cmd}` and rake's `sh "cmd"`. `%x{cmd}` has
# the benefit of returning the standard out of an executed command, enabling us
# to query the file system, e.g. `contents = %x{ls}`. The drawback to `%x{cmd}`
# is that on failure of a command (something returned non-zero) the return of
# `%x{cmd}` is just an empty string. As such, we can't know if we succeeded.
# Rake's `sh "cmd"`, on the other hand, will raise a RuntimeError if a command
# does not return 0, but doesn't return any of the stdout from the command -
# only true or false depending on its success or failure. With `ex(cmd)` we
# purport to both return the results of the command execution (ala `%x{cmd}`)
# while also raising an exception if a command does not succeed (ala `sh "cmd"`).
def ex(command)
  ret = %x[#{command}]
  unless $?.success?
    raise RuntimeError
  end
  ret
end
