# utility task to lay down packaging artifact files from erb templates
namespace :package do
  task :template, :workdir do |t, args|
    workdir = args.workdir

    if @build.templates
      if @build.templates.is_a?(Array)
        templates = FileList[@build.templates.map {|path| File.join(workdir, path)}]
      else
        STDERR.puts "templates must be an Array, not '#{@build.templates.class}'"
      end
    else
      templates = FileList["#{workdir}/ext/**/*.erb"].exclude(/#{workdir}\/ext\/(packaging|osx)/)
    end

    templates.each do |template|
      # process the template, stripping off the ERB extension
      erb(template, template[0..-5])
      rm_f(template)
    end
  end
end

