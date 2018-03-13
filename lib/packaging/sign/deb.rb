module Pkg::Sign::Deb
  module_function

  def sign_changes(file)
    # Lazy lazy lazy lazy lazy
    sign_program = "-p'gpg --use-agent --no-tty'" if ENV['RPM_GPG_AGENT']
    Pkg::Util::Execution.capture3("debsign #{sign_program} --re-sign -k#{Pkg::Config.gpg_key} #{file}")
  end
end
