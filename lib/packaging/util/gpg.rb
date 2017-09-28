module Pkg::Util::Gpg
  class << self

    def keychain
      if @keychain.nil?
        @keychain = Pkg::Util::Tool.find_tool('keychain')
      else
        @keychain
      end
    end

    def load_keychain
      unless @keychain_loaded
        unless ENV['RPM_GPG_AGENT']
          kill_keychain
          start_keychain
        end
        @keychain_loaded = TRUE
      end
    end

    def kill_keychain
      if keychain
        stdout, _, _ = Pkg::Util::Execution.capture3("#{keychain} -k mine")
        stdout
      end
    end

    def start_keychain
      if keychain
        keychain_output, _, _ = Pkg::Util::Execution.capture3("#{keychain} -q --agents gpg --eval #{Pkg::Config.gpg_key}")
        keychain_output.chomp!
        new_env = keychain_output.match(/GPG_AGENT_INFO=([^;]*)/)
        ENV["GPG_AGENT_INFO"] = new_env[1]
      else
        fail "Keychain is not installed, it is required to autosign using gpg."
      end
    end

    def sign_file(file)
      gpg ||= Pkg::Util::Tool.find_tool('gpg')

      if gpg
        use_tty = "--no-tty --use-agent" if ENV['RPM_GPG_AGENT']
        stdout, _, _ = Pkg::Util::Execution.capture3("#{gpg} #{use_tty} --armor --detach-sign -u #{Pkg::Config.gpg_key} #{file}")
        stdout
      else
        fail "No gpg available. Cannot sign #{file}."
      end
    end
  end
end
