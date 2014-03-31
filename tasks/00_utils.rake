#######################################################################
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                  !  DO NOT ADD TO THIS FILE  !                      #
#                                                                     #
#   Usage of this file to store utilities is deprecated. Any new      #
#   utilities should be added to new or existing classes in           #
#   lib/packaging/util. Any modified utilities should be migrated     #
#   to new or existing classes in lib/packaging/util as well.         #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#                                                                     #
#######################################################################





# Utility methods used by the various rake tasks

def check_var(varname,var=nil)
  var.nil? and fail "Requires #{varname} be set!"
end

def check_host(host)
  host == %x{hostname}.chomp! or fail "Requires host to be #{host}!"
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

def remote_ssh_cmd target, command
  Pkg::Util::Tool.check_tool('ssh')
  puts "Executing '#{command}' on #{target}"
  sh "ssh -t #{target} '#{command.gsub("'", "'\\\\''")}'"
end

def rsync_to *args
  Pkg::Util::Tool.check_tool('rsync')
  flags = "-rHlv -O --no-perms --no-owner --no-group --ignore-existing"
  source  = args[0]
  target  = args[1]
  dest    = args[2]
  puts "rsyncing #{source} to #{target}"
  sh "rsync #{flags} #{source} #{target}:#{dest}"
end

def rsync_from *args
  Pkg::Util::Tool.check_tool('rsync')
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

def load_keychain
  unless @keychain_loaded
    unless ENV['RPM_GPG_AGENT']
      kill_keychain
      start_keychain
    end
    @keychain_loaded = TRUE
  end
end

def kill_keychain
  %x{keychain -k mine}
end

def start_keychain
  keychain = %x{/usr/bin/keychain -q --agents gpg --eval #{Pkg::Config.gpg_key}}.chomp
  new_env = keychain.match(/(GPG_AGENT_INFO)=([^;]*)/)
  ENV[new_env[1]] = new_env[2]
end

def gpg_sign_file(file)
  gpg ||= Pkg::Util::Tool.find_tool('gpg')

  if gpg
    use_tty = "--no-tty --use-agent" if ENV['RPM_GPG_AGENT']
    sh "#{gpg} #{use_tty} --armor --detach-sign -u #{Pkg::Config.gpg_key} #{file}"
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
  if Pkg::Config.build_pe
    ENV['PE_VER'] = Pkg::Config.pe_version
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
  if Pkg::Util::Tool.find_tool('git') and File.exist?('.git')
    message ||= "changes"
    puts "Commiting changes:"
    puts
    diff = %x{git diff HEAD #{file}}
    puts diff
    %x{git commit #{file} -m "Commit #{message} in #{file}" &> /dev/null}
  end
end

def ship_gem(file)
  Pkg::Util::File.file_exists?("#{ENV['HOME']}/.gem/credentials", :required => true)
  %x{gem push #{file}}
end

def ask_yes_or_no
  return Pkg::Util.boolean_value(ENV['ANSWER_OVERRIDE']) unless ENV['ANSWER_OVERRIDE'].nil?
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

def git_tag(version)
  sh "git tag -s -u #{Pkg::Config.gpg_key} -m '#{version}' #{version}"
  $?.success or fail "Unable to tag repo at #{version}"
end

def rand_string
  rand.to_s.split('.')[1]
end

def git_bundle(treeish, appendix=nil, output_dir=nil)
  temp = output_dir || Pkg::Util::File.mktemp
  appendix ||= rand_string
  sh "git bundle create #{temp}/#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix} #{treeish} --tags"
  cd temp do
    sh "tar -czf #{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}.tar.gz #{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}"
    rm_rf "#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}"
  end
  "#{temp}/#{Pkg::Config.project}-#{Pkg::Config.version}-#{appendix}.tar.gz"
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
  sh "ssh -t #{host} '#{tar} -zxvf /tmp/#{tarball_name}.tar.gz -C /tmp/ ; git clone --recursive /tmp/#{tarball_name} /tmp/#{Pkg::Config.project}-#{appendix} ; cd /tmp/#{Pkg::Config.project}-#{appendix} ; rake package:bootstrap'"
  "/tmp/#{Pkg::Config.project}-#{appendix}"
end

# Given a BuildInstance object and a host, send its params to the host. Return
# the remote path to the params.
def remote_buildparams(host, build)
  params_file = build.config_to_yaml
  params_file_name = File.basename(params_file)
  params_dir = rand_string
  rsync_to(params_file, host, "/tmp/#{params_dir}/")
  "/tmp/#{params_dir}/#{params_file_name}"
end

def git_pull(remote, branch)
  sh "git pull #{remote} #{branch}"
end

def update_rpm_repo(dir)
  Pkg::Util::Tool.check_tool('createrepo')
  cd dir do
    sh "createrepo --checksum=sha --database --update ."
  end
end
alias :create_rpm_repo :update_rpm_repo

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
  curl = Pkg::Util::Tool.find_tool("curl") or fail "Couldn't find curl. Curl is required for posting jenkins to trigger a build. Please install curl and try again."
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
  create_url = "http://#{Pkg::Config.jenkins_build_host}/createItem?name=#{name}"
  form_args = ["-H", '"Content-Type: application/xml"', "--data-binary", "@#{xml_file}"]
  curl_form_data(create_url, form_args)
  "http://#{Pkg::Config.jenkins_build_host}/job/#{name}"
end

# Use the curl to check of a named job is defined on the jenkins server.  We
# curl the config file rather than just checking if the job exists by curling
# the job url and passing --head because jenkins will mistakenly return 200 OK
# if you issue multiple very fast requests just requesting the header.
def jenkins_job_exists?(name)
  job_url = "http://#{Pkg::Config.jenkins_build_host}/job/#{name}/config.xml"
  form_args = ["--silent", "--fail"]
  curl_form_data(job_url, form_args, :quiet => true)
end

def require_library_or_fail(library, gem_name = nil)
  gem_name ||= library
  begin
    require library
  rescue LoadError
    fail "Could not load #{gem_name}. #{gem_name} is required by the packaging repo for this task"
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
