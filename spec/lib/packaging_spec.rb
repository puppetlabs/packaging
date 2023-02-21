require 'spec_helper'

#   We load packaging.rb once, in spec_helper, to avoid reloading the library
#   and issuing warnings about already defined constants.
describe 'Pkg' do
  it 'should require the utilities module, Pkg::Util' do
    expect(Pkg::Util).to_not be_nil
  end

  it 'should require the configuration module, Pkg::Config' do
    expect(Pkg::Config).to_not be_nil
  end

  it 'should require the tar library, Pkg::Tar' do
    expect(Pkg::Tar).to_not be_nil
  end
end
