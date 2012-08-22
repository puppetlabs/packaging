namespace :package do
  desc "Create a source tar archive"
  task :tar => [ :clean ] do
    workdir = "pkg/#{@name}-#{@version}"
    mkdir_p workdir
    FileList[@files.split(' ')].each do |f|
      cp_pr f, workdir
    end
    erb "#{workdir}/ext/redhat/#{@name}.spec.erb", "#{workdir}/ext/redhat/#{@name}.spec"
    erb "#{workdir}/ext/debian/changelog.erb", "#{workdir}/ext/debian/changelog"
    rm_rf FileList["#{workdir}/ext/debian/*.erb", "#{workdir}/ext/redhat/*.erb"]
    cd "pkg" do
      sh "tar --exclude=.gitignore -zcf #{@name}-#{@version}.tar.gz #{@name}-#{@version}"
    end
    rm_rf workdir
    puts
    puts "Wrote #{`pwd`.strip}/pkg/#{@name}-#{@version}.tar.gz"
  end

  desc "Sign the tarball, defaults to PL key, pass GPG_KEY to override or edit build_defaults"
  task :sign_tar do
    unless File.exist? "pkg/#{@name}-#{@version}.tar.gz"
      STDERR.puts "No tarball exists. Try rake package:tar?"
      exit 1
    end
    gpg_sign_file "pkg/#{@name}-#{@version}.tar.gz"
  end
end
