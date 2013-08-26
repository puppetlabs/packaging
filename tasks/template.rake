# utility task to lay down packaging artifact files from erb templates
namespace :package do
  task :template, :workdir do |t, args|
    workdir = args.workdir

    FileList["#{workdir}/ext/**/*.erb"].exclude(/#{workdir}\/ext\/(packaging|osx)/).each do |template|
      # process the template, stripping off the ERB extension
      erb(template, template[0..-5])
      rm_f(template)
    end
  end
end

