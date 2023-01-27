require 'spec_helper'
require 'socket'
require 'open3'

describe 'Pkg::Util::Net' do
  let(:target)     { '/tmp/placething' }
  let(:target_uri) { 'http://google.com' }
  let(:content)    { 'stuff' }
  let(:rsync)      { '/bin/rsync' }
  let(:ssh)        { '/usr/local/bin/ssh' }
  let(:s3cmd)      { '/usr/local/bin/s3cmd' }

  describe '#fetch_uri' do
    context 'given a target directory' do
      it 'does nothing if the directory isn\'t writable' do
        allow(File).to receive(:writable?).with(File.dirname(target)).and_return(false)
        expect(File).not_to receive(:open)
        Pkg::Util::Net.fetch_uri(target_uri, target)
      end

      it 'writes the content of the uri to a file if directory is writable' do
        expect(File).to receive(:writable?).once.with(File.dirname(target)) { true }
        expect(File).to receive(:open).once.with(target, 'w')
        Pkg::Util::Net.fetch_uri(target_uri, target)
      end
    end
  end

  describe 'hostname utils' do
    describe 'hostname' do
      it 'should return the hostname of the current host' do
        allow(Socket).to receive(:gethostname).and_return('foo')
        expect(Pkg::Util::Net.hostname).to eq('foo')
      end
    end

    describe 'check_host' do
      context 'with required :true' do
        it 'should raise an exception if the passed host does not match the current host' do
          allow(Socket).to receive(:gethostname).and_return('foo')
          expect(Pkg::Util::Net).to receive(:check_host).and_raise(RuntimeError)
          expect { Pkg::Util::Net.check_host('bar', required: true) }.to raise_error(RuntimeError)
        end
      end

      context 'with required :false' do
        it 'should return nil if the passed host does not match the current host' do
          allow(Socket).to receive(:gethostname).and_return('foo')
          expect(Pkg::Util::Net.check_host('bar', required: false)).to be_nil
        end
      end
    end
  end

  describe 'remote_ssh_cmd' do
    it 'should be able to call via deprecated shim' do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('ssh').and_return(ssh)
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{ssh}  -t foo 'set -e;bar'")
      expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
      Pkg::Util::Net.remote_ssh_cmd('foo', 'bar', true)
    end
  end

  describe 'remote_execute' do
    it 'should fail if ssh is not present' do
      allow(Pkg::Util::Tool).to receive(:find_tool).with('ssh').and_raise(RuntimeError)
      expect(Pkg::Util::Tool).to receive(:check_tool).with('ssh').and_raise(RuntimeError)
      expect { Pkg::Util::Net.remote_execute('foo', 'bar') }.to raise_error(RuntimeError)
    end

    it 'should be able to not fail fast' do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('ssh').and_return(ssh)
      expect(Kernel).to receive(:system).with("#{ssh}  -t foo 'bar'")
      expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
      Pkg::Util::Net.remote_execute(
        'foo', 'bar', capture_output: false, extra_options: '', fail_fast: false
      )
    end

    it 'should be able to trace output' do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('ssh').and_return(ssh)
      expect(Kernel).to receive(:system).with("#{ssh}  -t foo 'set -x;bar'")
      expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
      Pkg::Util::Net.remote_execute(
        'foo', 'bar', capture_output: false, fail_fast: false, trace: true
      )
    end

    context 'without output captured' do
      it 'should execute a command :foo on a host :bar using Kernel' do
        expect(Pkg::Util::Tool).to receive(:check_tool).with("ssh").and_return(ssh)
        expect(Kernel).to receive(:system).with("#{ssh}  -t foo 'set -e;bar'")
        expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
        Pkg::Util::Net.remote_execute('foo', 'bar')
      end

      it 'should escape single quotes in the command' do
        expect(Pkg::Util::Tool).to receive(:check_tool).with('ssh').and_return(ssh)
        expect(Kernel).to receive(:system).with("#{ssh}  -t foo 'set -e;b'\\''ar'")
        expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
        Pkg::Util::Net.remote_execute('foo', "b'ar")
      end

      it 'should raise an error if ssh fails' do
        expect(Pkg::Util::Tool).to receive(:check_tool).with("ssh").and_return(ssh)
        expect(Kernel).to receive(:system).with("#{ssh}  -t foo 'set -e;bar'")
        expect(Pkg::Util::Execution).to receive(:success?).and_return(false)
        expect { Pkg::Util::Net.remote_execute('foo', 'bar') }
          .to raise_error(RuntimeError, /failed./)
      end
    end

    context 'with output captured' do
      it 'should execute a command :foo on a host :bar using Pkg::Util::Execution.capture3' do
        expect(Pkg::Util::Tool).to receive(:check_tool).with('ssh').and_return(ssh)
        expect(Pkg::Util::Execution).to receive(:capture3).with("#{ssh}  -t foo 'set -e;bar'")
        expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
        Pkg::Util::Net.remote_execute('foo', 'bar', capture_output: true)
      end

      it "should escape single quotes in the command" do
        expect(Pkg::Util::Tool).to receive(:check_tool).with('ssh').and_return(ssh)
        expect(Pkg::Util::Execution).to receive(:capture3).with("#{ssh}  -t foo 'set -e;b'\\''ar'")
        expect(Pkg::Util::Execution).to receive(:success?).and_return(true)
        Pkg::Util::Net.remote_execute('foo', "b'ar", capture_output: true)
      end

      it "should raise an error if ssh fails" do
        expect(Pkg::Util::Tool).to receive(:check_tool).with('ssh').and_return(ssh)
        expect(Pkg::Util::Execution).to receive(:capture3).with("#{ssh}  -t foo 'set -e;bar'")
        expect(Pkg::Util::Execution).to receive(:success?).and_return(false)
        expect { Pkg::Util::Net.remote_execute('foo', 'bar', capture_output: true) }
          .to raise_error(RuntimeError, /failed./)
      end
    end
  end

  describe '#rsync_to' do
    defaults = '--recursive --hard-links --links --verbose --omit-dir-times --no-perms --no-owner --no-group'
    it 'should fail if rsync is not present' do
      allow(Pkg::Util::Tool).to receive(:find_tool).with('rsync').and_raise(RuntimeError)
      expect(Pkg::Util::Tool).to receive(:check_tool).with('rsync').and_raise(RuntimeError)
      expect { Pkg::Util::Net.rsync_to('foo', 'bar', 'boo') }.to raise_error(RuntimeError)
    end

    it "should rsync 'thing' to 'foo@bar:/home/foo' with flags '#{defaults} --ignore-existing'" do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('rsync').and_return(rsync)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{rsync} #{defaults} --ignore-existing thing foo@bar:/home/foo", true)
      Pkg::Util::Net.rsync_to('thing', 'foo@bar', '/home/foo')
    end

    it "rsyncs 'thing' to 'foo@bar:/home/foo' with flags that don't include --ignore-existing" do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('rsync').and_return(rsync)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{rsync} #{defaults} thing foo@bar:/home/foo", true)
      Pkg::Util::Net.rsync_to('thing', 'foo@bar', '/home/foo', extra_flags: [])
    end

    it "rsyncs 'thing' to 'foo@bar:/home/foo' with flags that don't include arbitrary flags" do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('rsync').and_return(rsync)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{rsync} #{defaults} --foo-bar --and-another-flag thing foo@bar:/home/foo", true)
      Pkg::Util::Net.rsync_to('thing', 'foo@bar', '/home/foo',
                              extra_flags: ["--foo-bar", "--and-another-flag"])
    end
  end

  describe '#s3sync_to' do
    it 'should fail if s3cmd is not present' do
      expect(Pkg::Util::Tool)
        .to receive(:find_tool)
        .with('s3cmd', required: true)
        .and_raise(RuntimeError)
      expect(Pkg::Util::Execution)
        .to_not receive(:capture3).with("#{s3cmd} sync  'foo' s3://bar/boo/")
      expect { Pkg::Util::Net.s3sync_to('foo', 'bar', 'boo') }.to raise_error(RuntimeError)
    end

    it 'should fail if ~/.s3cfg is not present' do
      expect(Pkg::Util::Tool).to receive(:check_tool).with("s3cmd").and_return(s3cmd)
      expect(Pkg::Util::File)
        .to receive(:file_exists?)
        .with(File.join(ENV['HOME'], '.s3cfg'))
        .and_return(false)
      expect { Pkg::Util::Net.s3sync_to('foo', 'bar', 'boo') }
        .to raise_error(RuntimeError, /does not exist/)
    end

    it "should s3 sync 'thing' to 's3://foo@bar/home/foo/' with no flags" do
      expect(Pkg::Util::Tool).to receive(:check_tool).with("s3cmd").and_return(s3cmd)
      expect(Pkg::Util::File)
        .to receive(:file_exists?)
        .with(File.join(ENV['HOME'], '.s3cfg'))
        .and_return(true)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{s3cmd} sync  'thing' s3://foo@bar/home/foo/")
      Pkg::Util::Net.s3sync_to("thing", "foo@bar", "home/foo")
    end

    it "should s3sync 'thing' to 's3://foo@bar/home/foo/' with --delete-removed and --acl-public" do
      expect(Pkg::Util::Tool).to receive(:check_tool).with("s3cmd").and_return(s3cmd)
      expect(Pkg::Util::File)
        .to receive(:file_exists?)
        .with(File.join(ENV['HOME'], '.s3cfg'))
        .and_return(true)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{s3cmd} sync --delete-removed --acl-public 'thing' s3://foo@bar/home/foo/")
      Pkg::Util::Net.s3sync_to("thing", "foo@bar", "home/foo", ["--delete-removed", "--acl-public"])
    end
  end

  describe '#rsync_from' do
    defaults = "--recursive --hard-links --links --verbose --omit-dir-times --no-perms --no-owner --no-group"
    it 'should fail if rsync is not present' do
      allow(Pkg::Util::Tool).to receive(:find_tool).with('rsync').and_raise(RuntimeError)
      expect(Pkg::Util::Tool).to receive(:check_tool).with('rsync').and_raise(RuntimeError)
      expect { Pkg::Util::Net.rsync_from('foo', 'bar', 'boo') }.to raise_error(RuntimeError)
    end

    it 'should not include the flags \'--ignore-existing\' by default' do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('rsync').and_return(rsync)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{rsync} #{defaults} foo@bar:thing /home/foo", true)
      Pkg::Util::Net.rsync_from('thing', 'foo@bar', '/home/foo')
    end

    it "should rsync 'thing' from 'foo@bar' to '/home/foo' with flags '#{defaults}'" do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('rsync').and_return(rsync)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{rsync} #{defaults} foo@bar:thing /home/foo", true)
      Pkg::Util::Net.rsync_from('thing', 'foo@bar', '/home/foo')
    end

    it "rsyncs 'thing' from 'foo@bar:/home/foo' with flags that don't include arbitrary flags" do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('rsync').and_return(rsync)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{rsync} #{defaults} --foo-bar --and-another-flag foo@bar:thing /home/foo", true)
      Pkg::Util::Net.rsync_from('thing', 'foo@bar', '/home/foo',
                                extra_flags: ['--foo-bar', '--and-another-flag'])
    end
  end

  describe "#curl_form_data" do
    let(:curl) { '/bin/curl' }
    let(:form_data) { ['name=FOO'] }
    let(:options) { { quiet: true } }

    it 'should return false on failure' do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('curl').and_return(curl)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{curl} -i '#{target_uri}'").and_return(['stdout', 'stderr', 1])
      expect(Pkg::Util::Net.curl_form_data(target_uri)).to eq(['stdout', 1])
    end


    it "should curl with just the uri" do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('curl').and_return(curl)
      expect(Pkg::Util::Execution).to receive(:capture3).with("#{curl} -i '#{target_uri}'")
      Pkg::Util::Net.curl_form_data(target_uri)
    end

    it 'should curl with the form data and uri' do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('curl').and_return(curl)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{curl} -i #{form_data[0]} '#{target_uri}'")
      Pkg::Util::Net.curl_form_data(target_uri, form_data)
    end

    it 'should curl with form data, uri, and be quiet' do
      expect(Pkg::Util::Tool).to receive(:check_tool).with('curl').and_return(curl)
      expect(Pkg::Util::Execution)
        .to receive(:capture3)
        .with("#{curl} -i #{form_data[0]} '#{target_uri}'")
        .and_return(['stdout', 'stderr', 0])
      expect(Pkg::Util::Net.curl_form_data(target_uri, form_data, options)).to eq(['', 0])
    end
  end

  describe '#print_url_info' do
    it 'should output correct formatting' do
      expect(Pkg::Util::Net)
        .to receive(:puts)
        .with("\n////////////////////////////////////////////////////////////////////////////////\n\n
  Build submitted. To view your build progress, go to\n#{target_uri}\n\n
////////////////////////////////////////////////////////////////////////////////\n\n")
      Pkg::Util::Net.print_url_info(target_uri)
    end
  end
end
