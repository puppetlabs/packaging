# -*- ruby -*-
require 'spec_helper'

describe "Pkg::Util::Git_tag" do
  context "parse_ref!" do
    it "fails for a ref that doesn't exist'" do
      expect { Pkg::Util::Git_tag.new("git://github.com/puppetlabs/leatherman.git", "garbagegarbage") }.to raise_error(RuntimeError, /ERROR : Not a ref or sha!/)
    end
  end

  context "sha?" do
    it "sets ref type as a sha when passed a sha" do
      git_tag = Pkg::Util::Git_tag.new("git://github.com/puppetlabs/leatherman.git", "4eef05389ebf418b62af17406c7f9f13fa51f975")
      expect(git_tag.sha?).to eq(true)
    end
  end

  context "branch?" do
    it "sets ref type as a branch when passed a branch" do
      git_tag = Pkg::Util::Git_tag.new("git://github.com/puppetlabs/leatherman.git", "master")
      expect(git_tag.branch?).to eq(true)
    end
  end

  context "tag?" do
    it "sets ref type as a tag when passed a tag" do
      git_tag = Pkg::Util::Git_tag.new("git://github.com/puppetlabs/leatherman.git", "tags/0.6.2")
      expect(git_tag.tag?).to eq(true)
    end

    it "sets ref type as a tag when passed a fully qualified tag" do
      git_tag = Pkg::Util::Git_tag.new("git://github.com/puppetlabs/leatherman.git", "refs/tags/0.6.2")
      expect(git_tag.tag?).to eq(true)
    end
  end
end
