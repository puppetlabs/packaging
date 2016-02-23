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

#######################################################################
#                                                                     #
#         DEPRECATED METHODS: Please move any newly depreacted        #
#     methods into the following section so that we can easily        #
#              see what methods are left to librarify.                #
#                                                                     #
#######################################################################

def invoke_task(task, *args)
  Pkg::Util.deprecate('invoke_task', 'Pkg::Util::RakeUtils.invoke_task')
  Pkg::Util::RakeUtils.invoke_task(task, *args)
end

def rsync_to(*args)
  Pkg::Util.deprecate('rsync_to', 'Pkg::Util::Net.rsync_to')
  Pkg::Util::Net.rsync_to(args[0], args[1], args[2])
end

def rsync_from(*args)
  Pkg::Util.deprecate('rsync_from', 'Pkg::Util::Net.rsync_from')
  Pkg::Util::Net.rsync_from(args[0], args[1], args[2])
end

def mkdir_pr(*args)
  Pkg::Util.deprecate('mkdir_pr', 'FileUtils.mkdir_p')
  FileUtils.mkdir_p args
end

def ln(target, name)
  Pkg::Util.deprecate('ln', 'FileUtils.ln')
  FileUtils.ln(name, target, :force => true, :verbose => true)
end

def ln_sfT(src, dest)
  Pkg::Util.deprecate('ln_sfT')
  sh "ln -sfT #{src} #{dest}"
end

def git_commit_file(file, message = nil)
  Pkg::Util.deprecate('git_commit_file', 'Pkg::Util::Git.git_commit_file')
  Pkg::Util::Git.git_commit_file(file, message)
end

def git_bundle(treeish, appendix = nil, output_dir = nil)
  Pkg::Util.deprecate('git_bundle', 'Pkg::Util::Git.git_bundle')
  Pkg::Util::Git.git_bundle(treeish, appendix, output_dir)
end

def git_tag(version)
  Pkg::Util.deprecate('git_tag', 'Pkg::Util::Git.git_tag')
  Pkg::Util::Git.git_tag(version)
end

def git_pull(remote, branch)
  Pkg::Util.deprecate('git_pull', 'Pkg::Util::Git.git_pull')
  Pkg::Util::Git.git_pull(remote, branch)
end

def curl_form_data(uri, form_data = [], options = {})
  Pkg::Util.deprecate("curl_form_data", "Pkg::Util::Net.curl_form_data")
  Pkg::Util::Net.curl_form_data(uri, form_data, options)
end

def create_jenkins_job(name, xml_file)
  Pkg::Util.deprecate("create_jenkins_job", "Pkg::Util::Jenkins.create_jenkins_job")
  Pkg::Util::Jenkins.create_jenkins_job(name, xml_file)
end

def jenkins_job_exists?(name)
  Pkg::Util.deprecate("jenkins_job_exists", "Pkg::Util::Jenkins.jenkins_job_exists?")
  Pkg::Util::Jenkins.jenkins_job_exists?(name)
end

def print_url_info(url_string)
  Pkg::Util.deprecate("print_url_info", "Pkg::Util::Net.print_url_info")
  Pkg::Util::Net.print_url_info(url_string)
end

def retry_on_fail(args, &block)
  Pkg::Util.deprecate("retry_on_fail", "Pkg::Util::Execution.retry_on_fail")
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
  Pkg::Util.deprecate("ex", "Pkg::Util::Execution.ex")
  Pkg::Util::Execution.ex(command)
end

def load_keychain
  Pkg::Util.deprecate("load_keychain", "Pkg::Util::Gpg.load_keychain")
  Pkg::Util::Gpg.load_keychain
end

def kill_keychain
  Pkg::Util.deprecate("kill_keychain", "Pkg::Util::Gpg.kill_keychain")
  Pkg::Util::Gpg.kill_keychain
end

def start_keychain
  Pkg::Util.deprecate("start_keychain", "Pkg::Util::Gpg.start_keychain")
  Pkg::Util::Gpg.start_keychain
end

def gpg_sign_file(file)
  Pkg::Util.deprecate("gpg_sign_file", "Pkg::Util::Gpg.sign_file")
  Pkg::Util::Gpg.sign_file(file)
end

def check_var(varname, var)
  Pkg::Util.deprecate('check_var', 'Pkg::Util.check_var')
  Pkg::Util.check_var(varname, var)
end

def rand_string
  Pkg::Util.deprecate('invoke_task', 'Pkg::Util.rand_string')
  Pkg::Util.rand_string
end

def escape_html(uri)
  Pkg::Util.deprecate('escape_html', 'Pkg::Util::Net.escape_html')
  Pkg::Util::Net.escape_html(uri)
end

def add_param_to_uri(uri, param)
  Pkg::Util.deprecate('add_param_to_uri', 'Pkg::Util::Net.add_param_to_uri')
  Pkg::Util::Net.add_param_to_uri(uri, param)
end

def cp_pr(src, dest, options = {})
  Pkg::Util.deprecate('cp_pr', 'FileUtils.cp_r')
  mandatory = { :preserve => true }
  FileUtils.cp_r(src, dest, options.merge(mandatory))
end

def cp_p(src, dest, options = {})
  Pkg::Util.deprecate('cp_p', 'FileUtils.cp')
  mandatory = { :preserve => true }
  FileUtils.cp(src, dest, options.merge(mandatory))
end

def remote_set_immutable(host, files)
  Pkg::Util.deprecate('remote_set_immutable', 'Pkg::Util::Net.remote_set_immutable')
  Pkg::Util::Net.remote_set_immutable(host, files)
end

def ask_yes_or_no
  Pkg::Util.deprecate('ask_yes_or_no', 'Pkg::Util.ask_yes_or_no')
  Pkg::Util.ask_yes_or_no
end

def confirm_ship(files)
  Pkg::Util.deprecate('confirm_ship', 'Pkg::Util.confirm_ship')
  Pkg::Util.confirm_ship(files)
end

def deprecate(old_cmd, new_cmd = nil)
  Pkg::Util.deprecate('deprecate', 'Pkg::Util.deprecate')
  Pkg::Util.deprecate(old_cmd, new_cmd)
end

def remote_bootstrap(host, treeish, tar_cmd = nil, tarball = nil)
  Pkg::Util.deprecate('remote_bootstrap', 'Pkg::Util::Net.remote_bootstrap')
  Pkg::Util::Net.remote_bootstrap(host, treeish, tar_cmd, tarball)
end

def remote_buildparams(host, build)
  Pkg::Util.deprecate('remote_buildparams', 'Pkg::Util::Net.remote_buildparams')
  Pkg::Util::Net.remote_buildparams(host, build)
end

def ship_gem(file)
  Pkg::Util.deprecate('ship_gem', 'Pkg::Gem.ship')
  Pkg::Gem.ship(file)
end

def set_cow_envs(cow)
  Pkg::Util.deprecate('set_cow_envs', 'Pkg::Deb.set_cow_envs')
  Pkg::Deb.set_cow_envs(cow)
end
