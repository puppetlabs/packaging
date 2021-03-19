# Most projects set rdoc options in the context of gem building. However, mcollective
# generates its own rdoc package. We can reuse the Pkg::Config.gem_rdoc_options here

if Pkg::Config.build_doc
  begin
    require 'rdoc/task'
  rescue LoadError
    require 'rake/rdoctask'
  end

  namespace :package do
    RDoc::Task.new(:doc) do |rdoc|
      rdoc.rdoc_dir = 'doc'
      rdoc.title = "#{Pkg::Config.project} version #{Pkg::Config.version}"
      Pkg::Config.gem_rdoc_options&.each do |option|
          rdoc.options << option
        end
    end
  end
end
