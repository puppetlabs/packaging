# Utility methods used by the various rake tasks

def check_tool(tool)
  %x{which #{tool}}
  unless $?.success?
    STDERR.puts "#{tool} tool not found...exiting"
    exit 1
  end
end

def find_tool(tool)
  location = %x{which #{tool}}.chomp
  location if $?.success?
end

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
  template = File.read(erbfile)
  message = ERB.new(template, nil, "-")
  output = message.result(binding)
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
  %x{ssh #{target} '#{command}'}
end

def rsync_to *args
  check_tool('rsync')
  flags = "-Havxl -O --no-perms --no-owner --no-group"
  source  = args[0]
  target  = args[1]
  dest    = args[2]
  puts "rsyncing #{source} to #{target}"
  %x{rsync #{flags} #{source} #{ENV['USER']}@#{target}:#{dest}}
end

def scp_file_from(host,path,file)
  %x{scp #{ENV['USER']}@#{host}:#{path}/#{file} #{@tempdir}/#{file}}
end

def scp_file_to(host,path,file)
  %x{scp #{@tempdir}/#{file} #{ENV['USER']}@#{host}:#{path}}
end

def timestamp
  Time.now.strftime("%Y-%m-%d %H:%M:%S")
end

def get_dash_version
  if File.exists?('.git')
    %x{git describe}.chomp.split('-')[0..1].join('-').gsub('v','')
  else
    get_pwd_version
  end
end

def get_ips_version
  if File.exists?('.git')
    desc = %x{git describe}.chomp.split(/[.-]/)
    commits = %x{git log --oneline --no-merges | wc -l}.chomp.strip
    osrelease = %x{uname -r}.chomp
    "%s.%s.%s,#{osrelease}-%s" % [ desc[0],desc[1], desc[2], commits]
  else
    get_pwd_version
  end
end

def get_dot_version
  if File.exists?('.git')
    %x{git describe}.chomp.gsub('-', '.').split('.')[0..3].join('.').gsub('v', '')
  else
    get_pwd_version
  end
end

def get_pwd_version
  %x{pwd}.strip.split('.')[-1]
end

def get_debversion
  (@version.include?("rc") ? @version.sub(/rc[0-9]+/, '0.1\0') : "#{@version.gsub('-','.')}-1") + "#{@packager}#{get_debrelease}"
end

def get_origversion
  @debversion.split('-')[0]
end

def get_rpmversion
  @version.match(/^([0-9.]+)/)[1]
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
  ENV['RELEASE'] ||
    if @version.include?("rc")
      "0.1" + @version.gsub('-', '_').match(/rc[0-9]+.*/)[0]
    else
      "1"
    end
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
    STDERR.puts "No gpg available. Cannot sign tarball. Exiting..."
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
  %x{ln -f #{target} #{name}}
end

def git_commit_file(file)
  %x{which git &> /dev/null}
  if $?.success? and File.exist?('.git')
    %x{git commit #{file} -m "Commit changes to #{file}" &> /dev/null}
  end
end

def ship_gem(file)
  %x{gem push #{file}}
end

def x(v)
  puts %[#{v}]
  print %x[#{v}]
end

def ask_yes_or_no
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
  return TRUE if (var == TRUE || ( var.is_a?(String) && var.downcase == 'true' ))
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

