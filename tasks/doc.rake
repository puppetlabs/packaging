# Most projects set rdoc options in the context of gem building. However, mcollective
# generates its own rdoc package. We can reuse the @build.gem_rdoc_options here

if @build.build_doc
  begin
    require 'rdoc/task'
  rescue LoadError
    require 'rake/rdoctask'
  end

  namespace :package do
    RDoc::Task.new(:doc) do |rdoc|
      rdoc.rdoc_dir = 'doc'
      rdoc.title = "#{@build.project} version #{@build.version}"
      @build.gem_rdoc_options.each do |option|
        rdoc.options << option
      end unless @build.gem_rdoc_options.nil?
    end
  end
end
