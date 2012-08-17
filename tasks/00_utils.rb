# Utility methods used by the various rake tasks

def check_tool(tool)
  %x{which #{tool}}
  unless $?.success?
    STDERR.puts "#{tool} tool not found...exiting"
    exit 1
  end
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
  unless host == %x{'hostname'}.chomp!
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
    STDERR.puts 'Could not checkout dist git branch to build package from...exiting'
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

def get_version
  if File.exists?('.git')
    %x{git describe}.chomp.gsub('-', '.').split('.')[0..3].join('.').gsub('v', '')
  else
    %x{pwd}.strip!.split('.')[-1]
  end
end

def get_debversion
  @version.include?("rc") ? @version.sub(/rc[0-9]+/, '-0.1\0') : @version + "-1#{@packager}1"
end

def get_origversion
  @debversion.split('-')[0]
end

def get_rpmversion
  @version.match(/^([0-9.]+)/)[1]
end

def get_version_file_version
  File.open( @version_file ) {|io| io.grep(/VERSION = /)}[0].split()[-1]
end

def get_release
  ENV['RELEASE'] ||
    if @version.include?("rc")
      "0.1" + @version.gsub('-', '_').match(/rc[0-9]+.*/)[0]
    else
      "1"
    end
end

def gpg_sign_file(file)
   check_tool('gpg')
   %x{/usr/bin/gpg --armor --detach-sign -u #{@key_id} #{file}}
end

def mkdir_pr *args
  args.each do |arg|
    mkdir_p arg
  end
end
