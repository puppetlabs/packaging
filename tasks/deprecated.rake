# Emit useful messages for tasks that have been moved or removed.


deprecation_message_winston = "The ticket generation tasks have moved. These now live in Winston: https://github.com/puppetlabs/winston"

namespace :pl do
  desc "The ticket generation tasks have moved. These now live in Winston: https://github.com/puppetlabs/winston"
  task :new_server_platform_tickets do
    warn deprecation_message_winston
  end

  desc "The ticket generation tasks have moved. These now live in Winston: https://github.com/puppetlabs/winston"
  task :platform_addition do
    warn deprecation_message_winston
  end

  desc "The ticket generation tasks have moved. These now live in Winston: https://github.com/puppetlabs/winston"
  task :agent_tickets do
    warn deprecation_message_winston
  end

  desc "The ticket generation tasks have moved. These now live in Winston: https://github.com/puppetlabs/winston"
  task :platform_removal do
    warn deprecation_message_winston
  end

  desc "The ticket generation tasks have moved. These now live in Winston: https://github.com/puppetlabs/winston"
  task :puppet_agent_release_tickets do
    warn deprecation_message_winston
  end

  desc "The ticket generation tasks have moved. These now live in Winston: https://github.com/puppetlabs/winston"
  task :tickets do
    warn deprecation_message_winston
  end
end

if Pkg::Config.build_ips
  ips_dep_warning = "The IPS build tasks have been removed from puppetlabs/packaging. Please port all Solaris projects to vanagon (https://github.com/puppetlabs/vanagon)"
  namespace :package do
    namespace :ips do
      desc ips_dep_warning
      task :clean do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :clean_pkgs do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :prepare do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :prototmpl do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :protogen do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :protodeps do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :protomogrify do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :protomogrify do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :lint do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :package do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :createrepo do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :send do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :receive do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :dry_install do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :p5p do
        warn ips_dep_warning
      end

      desc ips_dep_warning
      task :ips do
        warn ips_dep_warning
      end
    end
  end

  namespace :pl do
    desc ips_dep_warning
    task :ips do
      warn ips_dep_warning
    end
  end
end
