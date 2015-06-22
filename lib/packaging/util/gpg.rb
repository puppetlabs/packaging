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
        Pkg::Util::Execution.ex("#{keychain} -k mine")
      end
    end

    def start_keychain
      if keychain
        keychain_output = Pkg::Util::Execution.ex("#{keychain} -q --agents gpg --eval #{Pkg::Config.gpg_key}").chomp
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
        Pkg::Util::Execution.ex("#{gpg} #{use_tty} --armor --detach-sign -u #{Pkg::Config.gpg_key} #{file}")
      else
        fail "No gpg available. Cannot sign #{file}."
      end
    end
  end
end
