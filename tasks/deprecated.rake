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
