module Pkg::Util::Gpg
  class << self
    # Please note that this method is not used in determining what key is used
    # to sign the debian repos. That is defined in the freight config that
    # lives on our internal repo staging host. The debian conf/distribution
    # files that are generated with this repo use the default gpg key to
    # reflect that.
    def key
      if Pkg::Config.gpg_key.nil? || Pkg::Config.gpg_key.empty?
        fail '`gpg_key` configuration variable is unset. Cannot continue.'
      end

      Pkg::Config.gpg_key
    end

    def keychain
      if @keychain.nil?
        @keychain = Pkg::Util::Tool.find_tool('keychain')
      else
        @keychain
      end
    end

    def load_keychain
      return if @keychain_loaded
      return if ENV['RPM_GPG_AGENT']

      kill_keychain
      start_keychain
      @keychain_loaded = true
    end

    def kill_keychain
      return unless keychain

      Pkg::Util::Execution.capture3("#{keychain} -k mine")[0]
    end

    def start_keychain
      unless keychain
        fail "Keychain is not installed, it is required to autosign using gpg."
      end

      keychain_output, = Pkg::Util::Execution.capture3("#{keychain} -q --agents gpg --eval #{key}")
      keychain_output.chomp!

      ENV['GPG_AGENT_INFO'] = keychain_output.match(/GPG_AGENT_INFO=([^;]*)/)[1]
    end

    def sign_file(file)
      gpg ||= Pkg::Util::Tool.find_tool('gpg')

      unless gpg
        fail "No gpg available. Cannot sign #{file}."
      end

      if File.exist? "#{file}.asc"
        warn "Signature on #{file} already exists, skipping."
        return true
      end

      use_tty = if ENV['RPM_GPG_AGENT']
                  '--no-tty --use-agent'
                else
                  ''
                end

      signing_command = "#{gpg} #{use_tty} --armor --detach-sign -u #{key} #{file}"
      puts "GPG signing with \"#{signing_command}\""
      Pkg::Util::Execution.capture3(signing_command)
      puts 'GPG signing succeeded.'
    end
  end
end
