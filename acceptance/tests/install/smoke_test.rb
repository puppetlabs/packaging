test_name 'puppet install smoketest' do

  step 'puppet install smoketest: verify \'facter --help\' can be successfully called on all hosts' do
    hosts.each do |host|
      on host, facter('--help')
    end
  end

  step 'puppet install smoketest: verify \'hiera --help\' can be successfully called on all hosts' do
    hosts.each do |host|
      on host, hiera('--help')
    end
  end

  step 'puppet install smoketest: verify \'puppet help\' can be successfully called on all hosts' do
    hosts.each do |host|
      on host, puppet('help')
    end
  end

  step 'puppet install smoketest: can get a configprint of the puppet server setting on all hosts' do
    hosts.each do |host|
      assert(!host.puppet['server'].empty?, 'can get a configprint of the puppet server setting')
    end
  end
end
