# -*- ruby -*-
require 'spec_helper'
require 'packaging/deb'

describe 'deb.rb' do
  describe '#set_cow_envs' do
    before(:each) do
      reset_env(['DIST', 'ARCH', 'PE_VER', 'BUILDMIRROR'])
      Pkg::Config.deb_build_mirrors = nil
      Pkg::Config.build_pe = nil
      Pkg::Config.pe_version = nil
    end

    after(:all) do
      reset_env(['DIST', 'ARCH', 'PE_VER', 'BUILDMIRROR'])
      Pkg::Config.deb_build_mirrors = nil
      Pkg::Config.build_pe = nil
      Pkg::Config.pe_version = nil
    end

    it 'should always set DIST and ARCH correctly' do
      Pkg::Deb.send(:set_cow_envs, 'base-wheezy-i386.cow')
      expect(ENV['DIST']).to eq('wheezy')
      expect(ENV['ARCH']).to eq('i386')
      expect(ENV['PE_VER']).to be nil
      expect(ENV['BUILDMIRROR']).to be nil
    end

    it 'should set BUILDMIRROR if Pkg::Config.deb_build_mirrors is set' do
      Pkg::Config.deb_build_mirrors = [
        'deb http://pl-build-tools.delivery.puppetlabs.net/debian __DIST__ main',
        'deb http://debian.is.awesome/wait no it is not'
      ]
      Pkg::Deb.send(:set_cow_envs, 'base-wheezy-i386.cow')
      expect(ENV['DIST']).to eq('wheezy')
      expect(ENV['ARCH']).to eq('i386')
      expect(ENV['PE_VER']).to be nil
      expect(ENV['BUILDMIRROR']).to eq('deb http://pl-build-tools.delivery.puppetlabs.net/debian wheezy main | deb http://debian.is.awesome/wait no it is not')
    end

    it 'should set PE_VER if Pkg::Config.build_pe is truthy' do
      Pkg::Config.build_pe = true
      Pkg::Config.pe_version = '3.2'
      Pkg::Deb.send(:set_cow_envs, 'base-wheezy-i386.cow')
      expect(ENV['DIST']).to eq('wheezy')
      expect(ENV['ARCH']).to eq('i386')
      expect(ENV['PE_VER']).to eq('3.2')
      expect(ENV['BUILDMIRROR']).to be nil
    end

    it 'should fail on a badly formatted cow' do
      expect { Pkg::Deb.send(:set_cow_envs, 'wheezy-i386') }.to raise_error(RuntimeError)
    end
  end
end
