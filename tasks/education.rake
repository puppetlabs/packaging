namespace :pl do
  namespace :jenkins do
    task :deploy_learning_vm, [:vm, :md5, :target_bucket, :target_directory] => "pl:fetch" do |t, args|

      vm = args.vm or fail ":vm is a required argument for #{t}"
      md5 = args.md5 or fail ":md5 is a required argument for #{t}"
      target_bucket = args.target_bucket or fail ":target_bucket is a required argument for #{t}"
      target_directory = args.target_directory or fail ":target_directory is a required argument for #{t}"

      Pkg::Util::Net.s3sync_to(vm, target_bucket, target_directory, ["--acl-public"])
      Pkg::Util::Net.s3sync_to(md5, target_bucket, target_directory, ["--acl-public"])

      puts "'#{vm}' and '#{md5}' have been shipped via s3 to '#{target_bucket}/#{target_directory}'"
    end

    task :deploy_training_vm, [:vm, :md5, :target_host, :target_directory] => "pl:fetch" do |t, args|

      vm = args.vm or fail ":vm is a required argument for #{t}"
      md5 = args.md5 or fail ":md5 is a required argument for #{t}"
      target_host = args.target_host or fail ":target_host is a required argument for #{t}"
      target_directory = args.target_directory or fail ":target_directory is a required argument for #{t}"

      # Determine VM we are trying to ship and set our link_target accordingly
      case vm
      when /student/
        link_target = ["puppet-student.ova", "puppet-vbox.zip", "puppet-vmware.zip"]
      when /master/
        link_target = ["puppet-master.ova"]
      when /training/
        link_target = ["puppet-training.ova"]
      else
        fail "We do not know the type of VM you are trying to ship. Cannot update symlinks"
      end

      # Ship VM and md5 to host
      Pkg::Util::Net.rsync_to(vm, target_host, target_directory)
      Pkg::Util::Net.rsync_to(md5, target_host, target_directory)

      # Update symlink to point to the VM we just shipped
      link_target.each do |link|
        link_path = File.join(target_directory, link)
        link_md5_path = "#{link_path}.md5"
        Pkg::Util::Net.remote_ssh_cmd(target_host, "if [[ -L '#{link_path}' ]] && [[ ! -e '#{link_path}' ]] ; then echo '#{link_path} is a broken link, deleting' ; unlink '#{link_path}' ; fi")
        Pkg::Util::Net.remote_ssh_cmd(target_host, "if [[ -L '#{link_md5_path}' ]] && [[ ! -e '#{link_md5_path}' ]] ; then echo '#{link_md5_path} is a broken link, deleting' ; unlink '#{link_md5_path}' ; fi")
        Pkg::Util::Net.remote_ssh_cmd(target_host, "cd #{target_directory} ; ln -sf #{File.basename(vm)} #{link}")
        Pkg::Util::Net.remote_ssh_cmd(target_host, "cd #{target_directory} ; ln -sf #{File.basename(md5)} #{link}.md5")
      end

      puts "'#{vm}' and '#{md5}' have been shipped via rsync to '#{target_host}/#{target_directory}'"
    end
  end
end
