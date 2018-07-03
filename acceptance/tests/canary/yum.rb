test_name 'Yum File Checks' do
  confine :to, :platform => /el/

  el_host = nil
  step 'Prep : Get el host to run checks on' do
    if default['platform'] =~ /^el-/
      el_host = default
    else
      # Grab the first host identifying itself as an Enterprise Linux platform
      el_host = hosts.select { |host| host['platform'] =~ /^el-/ }.first
    end
    # shouldn't be possible w/confine above, but it never hurts to assert...
    assert(el_host, 'Ran yum file checks without an el host')
  end

  artifact_path_on_sut = nil
  step 'Prep : Get artifact to check' do
    # When talking about this originally w/Ryan McKern & Morgan Rhodes, we talked
    # about potentially getting the code that originally puts an artifact at this
    # location to provide the URLs rather than having to duplicate that effort
    # here or using the duplication that we've built into beaker.
    #
    # Until we do this work, there's a question of where the tests should be getting
    # the artifacts they should test from. I'm using a placeholder to create the
    # tests, but perhaps to make this easier on us we should use a job parameter
    # and have the testing know how to get all artifacts from a folder URL? -- ki 12/7/16
    artifact_url = 'http://yum.puppetlabs.com/el/6/PC1/x86_64/puppet-agent-1.8.2-1.el6.x86_64.rpm'

    artifact_folder = create_tmpdir_on(el_host)
    artifact_path_on_sut = "#{artifact_folder}/puppet-agent-1.8.2-1.el6.x86_64.rpm"

    retry_on(el_host, "curl -o #{artifact_path_on_sut} #{artifact_url}", {
      :max_retries      => 30,
      :retry_intervals  => 2
    })

    assert(artifact_path_on_sut, 'Could not get artifact to test')
  end

  step 'Test : Artifact exists on SUT' do
    assert(el_host.file_exist?(artifact_path_on_sut), 'Artifact exists on host')
  end

  step 'Test : Artifact has a non-zero size' do
    ls_result = on(el_host, "ls -al #{artifact_path_on_sut}")
    assert(ls_result.exit_code == 0, 'Could get info about the file')

    output = ls_result.stdout.chomp
    file_size = output.split[4]
    assert(file_size != '0', "Artifact has a non-zero size: '#{file_size}'")
  end
end
