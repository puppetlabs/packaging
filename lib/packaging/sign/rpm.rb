module Pkg::Sign::Rpm
  module_function

  def sign(rpm, sign_flags = nil)
    # To enable support for wrappers around rpm and thus support for gpg-agent
    # rpm signing, we have to be able to tell the packaging repo what binary to
    # use as the rpm signing tool.
    rpm_executable = ENV['RPM'] || Pkg::Util::Tool.find_tool('rpm')

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

    # If gpg version is >=2.1, use the gpg1 binary to sign. Otherwise, use the standard sign command.
    gpg_executable = if gpg_version_greater_than_21?
                       "%__gpg /usr/bin/gpg1' --define '%__gpg_sign_cmd %{__gpg} gpg1"
                     else
                       '%__gpg_sign_cmd %{__gpg} gpg'
                     end

    # rubocop:disable Lint/NestedPercentLiteral
    gpg_signing_macro = %W[
      #{gpg_executable} #{sign_flags} #{input_flag}
      --batch --no-verbose --no-armor
      --no-secmem-warning -u %{_gpg_name}
      -sbo %{__signature_filename} %{__plaintext_filename}
    ].join(' ')
    # rubocop:enable Lint/NestedPercentLiteral

    sign_command = %W[
      #{rpm_executable} #{gpg_check_command}
      --define '%_gpg_name #{Pkg::Util::Gpg.key}'
      --define '#{gpg_signing_macro}' --addsign #{rpm}
    ].join(' ')

    # Try this up to 5 times, to allow for incorrect passwords
    Pkg::Util::Execution.retry_on_fail(:times => 5) do
      # This definition of %__gpg_sign_cmd is the default on modern rpm. We
      # accept extra flags to override certain signing behavior for older
      # versions of rpm, e.g. specifying V3 signatures instead of V4.
      Pkg::Util::Execution.capture3(sign_command)
    end
  end

  def legacy_sign(rpm)
    sign(rpm, "--force-v3-sigs --digest-algo=sha1")
  end

  def has_sig?(rpm)
    # This should allow the `Pkg::Util::Gpg.key` method to fail if gpg_key is
    # not set, before shelling out. We also only want the short key, all
    # lowercase, since that's what the `rpm -Kv` output uses.
    key = Pkg::Util::Gpg.key.downcase.chars.last(8).join
    signature_check_output = %x(rpm --checksig --verbose #{rpm})
    # If the signing key has not been loaded on the system this is running on,
    # the check will exit 1, even if the rpm is signed, so we can't use capture3,
    # which bails out with non-0 exit codes. Instead, check that the output
    # looks more-or-less how we expect it to.
    fail "Something went wrong checking the signature of #{rpm}." unless signature_check_output.include? "Header"
    return signature_check_output.include? "key ID #{key}"
  end

  def sign_all(rpm_directory)
    # Create a hash mapping full paths to basenames.
    # This will allow us to keep track of the different paths that may be
    # associated with a single basename, e.g. noarch packages.
    all_rpms = {}
    rpms_to_sign = Dir["#{rpm_directory}/**/*.rpm"]
    rpms_to_sign.each do |rpm_path|
      all_rpms[rpm_path] = File.basename(rpm_path)
    end
    # Delete a package, both from the signing server and from the rpm array, if
    # there are other packages with the same basename so that we only sign the
    # package once.
    all_rpms.each do |rpm_path, rpm_filename|
      if rpms_to_sign.map { |rpm| File.basename(rpm) }.count(rpm_filename) > 1
        FileUtils.rm(rpm_path)
        rpms_to_sign.delete(rpm_path)
      end
    end

    v3_rpms = []
    v4_rpms = []
    rpms_to_sign.each do |rpm|
      platform_tag = Pkg::Paths.tag_from_artifact_path(rpm)
      platform, version, = Pkg::Platforms.parse_platform_tag(platform_tag)

      # We don't sign AIX rpms
      next if platform_tag.include?('aix')

      if has_sig? rpm
        puts "#{rpm} is already signed, skipping . . ."
        next
      end

      case Pkg::Platforms.signature_format_for_platform_version(platform, version)
      when 'v3'
        v3_rpms << rpm
      when 'v4'
        v4_rpms << rpm
      else
        fail "Cannot find signature type for package '#{rpm}'"
      end
    end

    unless v3_rpms.empty?
      puts "Signing legacy (v3) rpms..."
      legacy_sign(v3_rpms.join(' '))
    end

    unless v4_rpms.empty?
      puts "Signing modern (v4) rpms..."
      sign(v4_rpms.join(' '))
    end

    # Using the map of paths to basenames, we re-hardlink the rpms we deleted.
    all_rpms.each do |link_path, rpm_filename|
      next if File.exist? link_path
      FileUtils.mkdir_p(File.dirname(link_path))
      # Find paths where the signed rpm has the same basename, but different
      # full path, as the one we need to link.
      paths_to_link_to = rpms_to_sign.select { |rpm| File.basename(rpm) == rpm_filename && rpm != link_path }
      paths_to_link_to.each do |path|
        FileUtils.ln(path, link_path, :force => true, :verbose => true)
      end
    end
  end

  def gpg_version_greater_than_21?
    gpg_version_output = %x(gpg --version)
    gpg_version = gpg_version_output.split(' ')[2]
    Gem::Version.new(gpg_version) >= Gem::Version.new('2.1.0')
  end
end
