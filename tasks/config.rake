namespace :config do
  desc "print Pkg::Config values for this repo"
  task :print do
    Pkg::Config.instance_values.each do |key, value|
      puts "#{key}: #{value}"
    end
  end
end
