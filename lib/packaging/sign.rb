module Pkg::Sign
  module_function

  def sign_rpm(rpm, sign_flags = nil)
    # To enable support for wrappers around rpm and thus support for gpg-agent
    # rpm signing, we have to be able to tell the packaging repo what binary to
    # use as the rpm signing tool.
    rpm_command = ENV['RPM'] || Pkg::Util::Tool.find_tool('rpm')

    # If we're using the gpg agent for rpm signing, we don't want to specify the
    # input for the passphrase, which is what '--passphrase-fd 3' does. However,
    # if we're not using the gpg agent, this is required, and is part of the
    # defaults on modern rpm. The fun part of gpg-agent signing of rpms is
    # specifying that the gpg check command always return true
    gpg_check_command = ''
    input_flag = ''
    if Pkg::Util.boolean_value(ENV['RPM_GPG_AGENT'])
      gpg_check_command = "--define '%__gpg_check_password_cmd /bin/true'"
    else
      input_flag = "--passphrase-fd 3"
    end

    # Try this up to 5 times, to allow for incorrect passwords
    Pkg::Util::Execution.retry_on_fail(:times => 5) do
      # This definition of %__gpg_sign_cmd is the default on modern rpm. We
      # accept extra flags to override certain signing behavior for older
      # versions of rpm, e.g. specifying V3 signatures instead of V4.
      %x(#{rpm_command} #{gpg_check_command} --define '%_gpg_name #{Pkg::Util::Gpg.key}' --define '%__gpg_sign_cmd %{__gpg} gpg #{sign_flags} #{input_flag} --batch --no-verbose --no-armor --no-secmem-warning -u %{_gpg_name} -sbo %{__signature_filename} %{__plaintext_filename}' --addsign #{rpm})
    end
  end

  def sign_legacy_rpm(rpm)
    sign_rpm(rpm, "--force-v3-sigs --digest-algo=sha1")
  end

  def rpm_has_sig(rpm)
    %x(rpm -Kv #{rpm} | grep "#{Pkg::Util::Gpg.key.downcase}" &> /dev/null)
    $?.success?
  end

  def sign_deb_changes(file)
    # Lazy lazy lazy lazy lazy
    sign_program = "-p'gpg --use-agent --no-tty'" if ENV['RPM_GPG_AGENT']
    %x(debsign #{sign_program} --re-sign -k#{Pkg::Config.gpg_key} #{file})
  end
end
