require 'spec_helper'
require 'packaging/sign'

describe 'Pkg::Sign' do
  describe 'Pkg::Sign::Rpm' do

    before :each do
      allow(Pkg::Config).to receive(:gpg_key).and_return('7F438280EF8D349F')
    end

    describe '#has_sig?' do
      let(:rpm) { 'foo.rpm' }
      let(:el7_signed_response) { <<-DOC
Header V4 RSA/SHA256 Signature, key ID ef8d349f: NOKEY
Header SHA1 digest: OK (3cb7e9861e8bc09783a1b6c8d88243a3c16daa81)
V4 RSA/SHA256 Signature, key ID ef8d349f: NOKEY
MD5 digest: OK (d5f06ba2a9053de532326d0659ec0d11)
DOC
      }
      let(:el5_signed_response) { <<-DOC
Header V3 RSA/SHA1 signature: NOKEY, key ID ef8d349f
Header SHA1 digest: OK (12ea7bd578097a3aecc5deb8ada6aca6147d68e3)
V3 RSA/SHA1 signature: NOKEY, key ID ef8d349f
MD5 digest: OK (27353c6153068a3c9902fcb4ad5b8b92)
DOC
      }
      let(:sles12_signed_response) { <<-DOC
Header V4 RSA/SHA256 Signature, key ID ef8d349f: NOKEY
Header SHA1 digest: OK (e713487cf21ebeb933aefd5ec9211a34603233d2)
V4 RSA/SHA256 Signature, key ID ef8d349f: NOKEY
MD5 digest: OK (3093a09ac39bc17751f913e19ca74432)
DOC
      }
      let(:unsigned_response) { <<-DOC
Header SHA1 digest: OK (f9404cc95f200568c2dbb1fd24e1119e3e4a40a9)
MD5 digest: OK (816095f3cee145091c3fa07a0915ce85)
DOC
      }
      it 'returns true if rpm has been signed (el7)' do
        allow(Pkg::Util::Execution).to receive(:capture3).and_return([el7_signed_response, '', 0])
        expect(Pkg::Sign::Rpm.has_sig?(rpm)).to be true
      end
      it 'returns true if rpm has been signed (el5)' do
        allow(Pkg::Util::Execution).to receive(:capture3).and_return([el5_signed_response, '', 0])
        expect(Pkg::Sign::Rpm.has_sig?(rpm)).to be true
      end
      it 'returns true if rpm has been signed (sles12)' do
        allow(Pkg::Util::Execution).to receive(:capture3).and_return([sles12_signed_response, '', 0])
        expect(Pkg::Sign::Rpm.has_sig?(rpm)).to be true
      end
      it 'returns false if rpm has not been signed' do
        allow(Pkg::Util::Execution).to receive(:capture3).and_return([unsigned_response, '', 0])
        expect(Pkg::Sign::Rpm.has_sig?(rpm)).to be false
      end
      it 'fails if gpg_key is not set' do
        allow(Pkg::Config).to receive(:gpg_key).and_return(nil)
        expect { Pkg::Sign::Rpm.has_sig?(rpm) }.to raise_error(RuntimeError, /You need to set `gpg_key` in your build defaults./)
      end
    end

    describe '#sign_all' do
      let(:rpm_directory) { 'foo' }
      let(:rpms_not_to_sign) { [
        "#{rpm_directory}/aix/6.1/PC1/ppc/puppet-agent-5.5.3-1.aix6.1.ppc.rpm",
        "#{rpm_directory}/aix/7.1/PC1/ppc/puppet-agent-5.5.3-1.aix7.1.ppc.rpm",
      ] }
      let(:v3_rpms) { [
        "#{rpm_directory}/el/5/PC1/i386/puppet-agent-5.5.3-1.el5.i386.rpm",
        "#{rpm_directory}/sles/11/PC1/x86_64/puppet-agent-5.5.3-1.sles11.x86_64.rpm",
      ] }
      let(:v4_rpms) { [
        "#{rpm_directory}/el/7/PC1/aarch64/puppet-agent-5.5.3-1.el7.aarch64.rpm",
        "#{rpm_directory}/sles/12/PC1/s390x/puppet-agent-5.5.3-1.sles12.s390x.rpm",
      ] }
      let(:rpms) { rpms_not_to_sign + v3_rpms + v4_rpms }
      let(:already_signed_rpms) { [
        "#{rpm_directory}/cisco-wrlinux/7/PC1/x86_64/puppet-agent-5.5.3-1.cisco_wrlinux7.x86_64.rpm",
        "#{rpm_directory}/el/6/PC1/x86_64/puppet-agent-5.5.3-1.el6.x86_64.rpm",
      ] }
      let(:noarch_rpms) { [
        "#{rpm_directory}/el/6/puppet5/i386/puppetserver-5.3.3-1.el6.noarch.rpm",
        "#{rpm_directory}/el/6/puppet5/x86_64/puppetserver-5.3.3-1.el6.noarch.rpm",
        "#{rpm_directory}/el/7/puppet5/i386/puppetserver-5.3.3-1.el7.noarch.rpm",
        "#{rpm_directory}/el/7/puppet5/x86_64/puppetserver-5.3.3-1.el7.noarch.rpm",
        "#{rpm_directory}/sles/12/puppet5/i386/puppetserver-5.3.3-1.sles12.noarch.rpm",
        "#{rpm_directory}/sles/12/puppet5/x86_64/puppetserver-5.3.3-1.sles12.noarch.rpm"
      ] }

      it 'signs both v3 and v4 rpms' do
        allow(Dir).to receive(:[]).with("#{rpm_directory}/**/*.rpm").and_return(rpms)
        rpms.each do |rpm|
          allow(Pkg::Sign::Rpm).to receive(:has_sig?).and_return(false)
        end
        expect(Pkg::Sign::Rpm).to receive(:legacy_sign).with(v3_rpms.join(' '))
        expect(Pkg::Sign::Rpm).to receive(:sign).with(v4_rpms.join(' '))
        Pkg::Sign::Rpm.sign_all(rpm_directory)
      end

      it 'does not sign AIX rpms' do
        allow(Dir).to receive(:[]).with("#{rpm_directory}/**/*.rpm").and_return(rpms_not_to_sign)
        allow(Pkg::Sign::Rpm).to receive(:has_sig?)
        expect(Pkg::Sign::Rpm).to_not receive(:legacy_sign)
        expect(Pkg::Sign::Rpm).to_not receive(:sign)
        Pkg::Sign::Rpm.sign_all(rpm_directory)
      end

      it 'does not sign already-signed rpms' do
        allow(Dir).to receive(:[]).with("#{rpm_directory}/**/*.rpm").and_return(already_signed_rpms)
        already_signed_rpms.each do |rpm|
          allow(Pkg::Sign::Rpm).to receive(:has_sig?).and_return(true)
        end
        expect(Pkg::Sign::Rpm).to_not receive(:legacy_sign)
        expect(Pkg::Sign::Rpm).to_not receive(:sign)
        Pkg::Sign::Rpm.sign_all(rpm_directory)
      end

      it 'deletes and relinks rpms with the same basename' do
        allow(Dir).to receive(:[]).with("#{rpm_directory}/**/*.rpm").and_return(noarch_rpms)
        allow(Pkg::Sign::Rpm).to receive(:sign)
        allow(Pkg::Sign::Rpm).to receive(:has_sig?)
        expect(FileUtils).to receive(:rm).exactly(noarch_rpms.count/2).times
        expect(FileUtils).to receive(:ln).exactly(noarch_rpms.count/2).times
        Pkg::Sign::Rpm.sign_all(rpm_directory)
      end

      it 'does not fail if there are no rpms to sign' do
        allow(Dir).to receive(:[]).with("#{rpm_directory}/**/*.rpm").and_return([])
        expect(Pkg::Sign::Rpm.sign_all(rpm_directory)).to_not raise_error
      end
    end
  end
end
