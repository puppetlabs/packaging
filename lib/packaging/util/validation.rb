module Pkg::Util::Validation
  class << self
    def confirm_tagged_checkout
      if Pkg::Util::Version.git_tagged_checkout?
        answer = Pkg::Util::Prompt.confirm_tag(Pkg::Util::Version.git_tag)
        fail("canceled by user") unless answer
      else
        Pkg::Util::Notify.not_on_tag
        fail "attempted to ship without a tag"
      end
    end

    def fail_on_branch
      unless Pkg::Util::Version.git_detached?
        Pkg::Util::Notify.on_branch
        fail "attempted to ship from a branch, not a tag"
      end
    end
  end
end
