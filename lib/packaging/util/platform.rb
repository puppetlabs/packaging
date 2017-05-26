module Pkg::Util::Platform
  module_function
  ##########################################################################
  # DEPRECATED METHODS
  #
  def platform_tags
    Pkg::Util.deprecate('Pkg::Util::Platform.platform_tags', 'Pkg::Platforms.platform_tags')
    Pkg::Platforms.platform_tags
  end

  def platform_lookup(platform_tag)
    Pkg::Util.deprecate('Pkg::Util::Platform.platform_lookup', 'Pkg::Platforms.platform_lookup')
    Pkg::Platforms.platform_lookup(platform_tag)
  end

  def parse_platform_tag(platform_tag)
    Pkg::Util.deprecate('Pkg::Util::Platform.parse_platform_tag', 'Pkg::Platforms.parse_platform_tag')
    Pkg::Platforms.parse_platform_tag(platform_tag)
  end

  def get_attribute(platform_tag, attribute_name)
    Pkg::Util.deprecate('Pkg::Util::Platform.get_attribute', 'Pkg::Platforms.get_attribute')
    Pkg::Platforms.get_attribute(platform_tag, attribute_name)
  end

  def artifacts_path(platform_tag, package_url = nil)
    Pkg::Util.deprecate('Pkg::Util::Platform.artifacts_path', 'Pkg::Paths.artifacts_path')
    Pkg::Paths.artifacts_path(platform_tag, package_url = nil)
  end

  def repo_path(platform_tag)
    Pkg::Util.deprecate('Pkg::Util::Platform.repo_path', 'Pkg::Paths.repo_path')
    Pkg::Paths.repo_path(platform_tag)
  end

  def repo_config_path(platform_tag)
    Pkg::Util.deprecate('Pkg::Util::Platform.repo_config_path', 'Pkg::Paths.repo_config_path')
    Pkg::Paths.repo_config_path(platform_tag)
  end
end
