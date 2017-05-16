module Pkg::Rpm::Version
  class << self

    # Utility method to return the dist method if this is a redhat box. We use this
    # in rpm packaging to define a dist macro, and we use it in the pl:fetch task
    # to disable ssl checking for redhat 5 because it has a certs bundle so old by
    # default that it's useless for our purposes.
    def el_version
      if File.exists?('/etc/fedora-release')
        nil
      elsif File.exists?('/etc/redhat-release')
        rpm = Pkg::Util::Tool.find_tool('rpm', :required => true)
        stdout, _, _ = Pkg::Util::Execution.capture3("#{rpm} -q --qf \"%{VERSION}\" $(#{rpm} -q --whatprovides /etc/redhat-release )")
        stdout
      end
    end
  end
end
