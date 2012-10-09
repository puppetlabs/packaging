namespace :package do
  desc "Create a source tar archive"
  task :tar => [ :clean ] do
    Rake::Task["package:doc"].invoke if @build_doc
    tar = ENV['TAR'] || 'tar'
    workdir = "pkg/#{@name}-#{@version}"
    mkdir_p(workdir)
    FileList[@files.split(' ')].each do |f|
      cp_pr(f, workdir)
    end
    Rake::Task["package:template"].invoke(workdir)
    cd "pkg" do
      sh "#{tar} --exclude=.gitignore --exclude=ext/#{@packaging_repo} -zcf #{@name}-#{@version}.tar.gz #{@name}-#{@version}"
    end
    rm_rf(workdir)
    puts
    puts "Wrote #{`pwd`.strip}/pkg/#{@name}-#{@version}.tar.gz"
  end
end
