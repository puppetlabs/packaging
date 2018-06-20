require 'spec_helper'
require 'packaging/sign'

describe 'Pkg::Sign' do
  describe 'Pkg::Sign::Rpm' do

    before :each do
      allow(Pkg::Config).to receive(:gpg_key).and_return('7F438280EF8D349F')
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
