# Load the packaging repo libraries

require File.join(File.dirname(__FILE__), 'lib', 'packaging.rb')

# Load packaging repo tasks

# These are ordered

PACKAGING_ROOT = __dir__

@using_loader = true

Pkg::Util::RakeUtils.load_packaging_tasks(PACKAGING_ROOT)
