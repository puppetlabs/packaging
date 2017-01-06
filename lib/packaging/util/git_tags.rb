module Pkg::Util
  class Git_tag
    attr_reader :address, :ref, :ref_name, :ref_type, :branch_name

    GIT = Pkg::Util::Tool::GIT
    DEVNULL = Pkg::Util::OS::DEVNULL

    # A SHA1 sum is 20 characters long, but Git will match on
    # the first ~8 or so. And 8 is long enough for fun test sums
    # like 'cafebeef' or 'deadfeed`.
    SHA1 = /[0-9A-F]{8,20}/i

    def initialize(address, reference)
      @address = address
      @ref = reference
      parse_ref!
    end

    # Parse ref in one of three ways: if the ref is already in a good format just grab
    # the ref type from the string. if it's not, check if it's a sha, if that is true
    # then list it as a sha. finally if it's neither of those fetch the full ref and
    # parse that.
    def parse_ref!
      if ref?
        split_ref(ref)
      elsif sha?
        @ref_type = "sha"
      else
        split_ref(fetch_full_ref)
      end
    end

    # Split the ref based on slashes, set ref_name and ref_type based on the last two
    # items from the split. i.e. refs/tags/1.1.1 would return:
    #       @ref_name => 1.1.1       @ref_type => tags
    def split_ref(ref)
      ref_parts = ref.split('/', 3)
      @ref_name = ref_parts.pop
      @ref_type = ref_parts.pop
      [@ref_type, @ref_name]
    end

    # Fetch the full ref using ls-remote, this should raise an error if it returns non-zero
    # because that means this ref doesn't exist in the repo
    def fetch_full_ref
      stdout, _, _ = Pkg::Util::Execution.capture3("#{GIT} ls-remote --tags --heads --exit-code #{address} #{ref}")
      stdout.split.last
    rescue RuntimeError => e
      raise "ERROR : Not a ref or sha!\n#{e}"
    end

    def branch_name
      branch? ? ref_name : nil
    end

    def ref?
      `#{GIT} check-ref-format #{ref} >#{DEVNULL} 2>&1`
      $?.success?
    end

    def branch?
      ref_type.downcase == "heads"
    end

    def tag?
      ref_type.downcase == "tags"
    end

    def sha?
      !!(ref =~ SHA1)
    end
  end
end
