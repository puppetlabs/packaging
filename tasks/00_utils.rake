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

def check_var(varname, var = nil)
  var.nil? and fail "Requires #{varname} be set!"
  var
end

def cp_pr(src, dest, options = {})
  mandatory = { :preserve => true }
  cp_r(src, dest, options.merge(mandatory))
end

def cp_p(src, dest, options = {})
  mandatory = { :preserve => true }
  cp(src, dest, options.merge(mandatory))
end

def set_cow_envs(cow)
  elements = /base-(.*)-(.*)\.cow/.match(cow)
  if elements.nil?
    fail "Didn't get a matching cow, e.g. 'base-squeeze-i386'"
  end
  dist = elements[1]
  arch = elements[2]
  if Pkg::Config.build_pe
    ENV['PE_VER'] = Pkg::Config.pe_version
  end
  if Pkg::Config.deb_build_mirrors
    ENV['BUILDMIRROR'] = Pkg::Config.deb_build_mirrors.map do |mirror|
      mirror.gsub(/__DIST__/, dist)
    end.join(' | ')
  end
  ENV['DIST'] = dist
  ENV['ARCH'] = arch
  if dist =~ /cumulus/
    ENV['NETWORK_OS'] = 'cumulus'
  end
end

def ship_gem(file)
  Pkg::Util::File.file_exists?("#{ENV['HOME']}/.gem/credentials", :required => true)
  Pkg::Util::Execution.ex("gem push #{file}")
  begin
    Pkg::Util::Tool.check_tool("stickler")
    Pkg::Util::Execution.ex("stickler push #{file} --server=#{Pkg::Config.internal_gem_host} 2>/dev/null")
    puts "#{file} pushed to stickler server at #{Pkg::Config.internal_gem_host}"
  rescue
    puts "##########################################\n#"
    puts "#  Stickler failed, ensure it's installed"
    puts "#  and you have access to #{Pkg::Config.internal_gem_host} \n#"
    puts "##########################################"
  end
  Pkg::Util::Execution.retry_on_fail(:times => 3) do
    Pkg::Util::Net.rsync_to("#{file}*", Pkg::Config.gem_host, Pkg::Config.gem_path)
  end
end

def ask_yes_or_no
  return Pkg::Util.boolean_value(ENV['ANSWER_OVERRIDE']) unless ENV['ANSWER_OVERRIDE'].nil?
  answer = STDIN.gets.downcase.chomp
  return TRUE if answer =~ /^y$|^yes$/
  return FALSE if answer =~ /^n$|^no$/
  puts "Nope, try something like yes or no or y or n, etc:"
  ask_yes_or_no
end

def confirm_ship(files)
  STDOUT.puts "The following files have been built and are ready to ship:"
  files.each { |file| STDOUT.puts "\t#{file}\n" unless File.directory?(file) }
  STDOUT.puts "Ship these files?? [y,n]"
  ask_yes_or_no
end

def rand_string
  rand.to_s.split('.')[1]
end

# We take a tar argument for cases where `tar` isn't best, e.g. Solaris.  We
# also take an optional argument of the tarball containing the git bundle to
# use.
def remote_bootstrap(host, treeish, tar_cmd = nil, tarball = nil)
  unless tar = tar_cmd
    tar = 'tar'
  end
  tarball ||= Pkg::Util::Git.git_bundle(treeish)
  tarball_name = File.basename(tarball).gsub('.tar.gz', '')
  Pkg::Util::Net.rsync_to(tarball, host, '/tmp')
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
  Pkg::Util::Net.rsync_to(params_file, host, "/tmp/#{params_dir}/")
  "/tmp/#{params_dir}/#{params_file_name}"
end

def deprecate(old_cmd, new_cmd = nil)
  msg = "!! #{old_cmd} is deprecated."
  if new_cmd
    msg << " Please use #{new_cmd} instead."
  end
  STDOUT.puts
  STDOUT.puts(msg)
  STDOUT.puts
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
  Pkg::Util::Net.remote_ssh_cmd(host, "sudo chattr +i #{files.join(" ")}")
end

#######################################################################
#                                                                     #
#         DEPRECATED METHODS: Please move any newly depreacted        #
#     methods into the following section so that we can easily        #
#              see what methods are left to librarify.                #
#                                                                     #
#######################################################################

def invoke_task(task, *args)
  deprecate('invoke_task', 'Pkg::Util::RakeUtils.invoke_task')
  Pkg::Util::RakeUtils.invoke_task(task, *args)
end

def rsync_to(*args)
  deprecate('rsync_to', 'Pkg::Util::Net.rsync_to')
  Pkg::Util::Net.rsync_to(args[0], args[1], args[2])
end

def rsync_from(*args)
  deprecate('rsync_from', 'Pkg::Util::Net.rsync_from')
  Pkg::Util::Net.rsync_from(args[0], args[1], args[2])
end

def mkdir_pr(*args)
  deprecate('mkdir_pr', 'FileUtils.mkdir_p')
  FileUtils.mkdir_p args
end

def ln(target, name)
  deprecate('ln', 'FileUtils.ln')
  FileUtils.ln(name, target, :force => true, :verbose => true)
end

def ln_sfT(src, dest)
  deprecate('ln_sfT')
  sh "ln -sfT #{src} #{dest}"
end

def git_commit_file(file, message = nil)
  deprecate('git_commit_file', 'Pkg::Util::Git.git_commit_file')
  Pkg::Util::Git.git_commit_file(file, message)
end

def git_bundle(treeish, appendix = nil, output_dir = nil)
  deprecate('git_bundle', 'Pkg::Util::Git.git_bundle')
  Pkg::Util::Git.git_bundle(treeish, appendix, output_dir)
end

def git_tag(version)
  deprecate('git_tag', 'Pkg::Util::Git.git_tag')
  Pkg::Util::Git.git_tag(version)
end

def git_pull(remote, branch)
  deprecate('git_pull', 'Pkg::Util::Git.git_pull')
  Pkg::Util::Git.git_pull(remote, branch)
end

def curl_form_data(uri, form_data = [], options = {})
  deprecate("curl_form_data", "Pkg::Util::Net.curl_form_data")
  Pkg::Util::Net.curl_form_data(uri, form_data, options)
end

def create_jenkins_job(name, xml_file)
  deprecate("create_jenkins_job", "Pkg::Util::Jenkins.create_jenkins_job")
  Pkg::Util::Jenkins.create_jenkins_job(name, xml_file)
end

def jenkins_job_exists?(name)
  deprecate("jenkins_job_exists", "Pkg::Util::Jenkins.jenkins_job_exists?")
  Pkg::Util::Jenkins.jenkins_job_exists?(name)
end

def print_url_info(url_string)
  deprecate("print_url_info", "Pkg::Util::Net.print_url_info")
  Pkg::Util::Net.print_url_info(url_string)
end

def retry_on_fail(args, &block)
  deprecate("retry_on_fail", "Pkg::Util::Execution.retry_on_fail")
  Pkg::Util::Execution.retry_on_fail(args, &block)
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
  deprecate("ex", "Pkg::Util::Execution.ex")
  Pkg::Util::Execution.ex(command)
end

def load_keychain
  deprecate("load_keychain", "Pkg::Util::Gpg.load_keychain")
  Pkg::Util::Gpg.load_keychain
end

def kill_keychain
  deprecate("kill_keychain", "Pkg::Util::Gpg.kill_keychain")
  Pkg::Util::Gpg.kill_keychain
end

def start_keychain
  deprecate("start_keychain", "Pkg::Util::Gpg.start_keychain")
  Pkg::Util::Gpg.start_keychain
end

def gpg_sign_file(file)
  deprecate("gpg_sign_file", "Pkg::Util::Gpg.sign_file")
  Pkg::Util::Gpg.sign_file(file)
end
