# utility task to lay down packaging artifact files from erb templates
namespace :package do
  task :template, :workdir do |t, args|
    workdir = args.workdir
    erb("#{workdir}/ext/redhat/#{@name}.spec.erb", "#{workdir}/ext/redhat/#{@name}.spec")
    erb("#{workdir}/ext/debian/changelog.erb", "#{workdir}/ext/debian/changelog")
    rm_rf(FileList["#{workdir}/ext/debian/*.erb", "#{workdir}/ext/redhat/*.erb"])
  end
end

