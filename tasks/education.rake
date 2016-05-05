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
  end
end
