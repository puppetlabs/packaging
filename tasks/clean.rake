desc "Clean all built packages, eg rm -rf pkg"
task :clean do
  rm_rf 'pkg'
end
