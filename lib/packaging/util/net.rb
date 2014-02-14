# Utility methods for handling network calls and interactions

module Pkg::Util::Net

  class << self

    # This simple method does an HTTP get of a URI and writes it to a file
    # in a slightly more platform agnostic way than curl/wget
    def fetch_uri(uri, target)
      require 'open-uri'
      if Pkg::Util::File.file_writable?(File.dirname(target))
        File.open(target, 'w') { |f| f.puts( open(uri).read ) }
      end
    end
  end
end
