# Set up paths to system tools we use in the packaging repo
# no matter what distribution we're packaging for

module Pkg::Util

  GIT = find_tool('git', :required => :true)

end

