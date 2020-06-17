require 'artifactory'

module ArtifactoryExtensions
  module ClassMethods
    #
    # Search for an artifact in a repo using an Ant-like pattern.
    # Unlike many Artifactory searches, this one is restricted to a single
    # repository.
    #
    # @example Search in a repository named 'foo_local' for an artifact in a directory containing
    #   the word "recent", named "artifact[0-9].txt"
    #   Artifact.pattern_search(pattern: '*recent*/artifact[0-9].txt',
    #                           repo: 'foo_local')
    #
    # @param [Hash] options
    #   A hash of options, as follows:
    #
    # @option options [Artifactory::Client] :client
    #   the client object to make the request with
    # @option options [String] :pattern
    #   the Ant-like pattern to use for finding artifacts within the repos. Note that the
    #   Ant pattern '**' is barred in this case by JFrog.
    # @option options [String] :repo
    #   the repo to search
    #
    # @return [Array<Resource::Artifact>]
    #   a list of artifacts that match the query
    #
    def pattern_search(options = {})
      client = extract_client!(options)
      params = Artifactory::Util.slice(options, :pattern, :repo)
      pattern_search_parameter = { :pattern => "#{params[:repo]}:#{params[:pattern]}" }
      response = client.get('/api/search/pattern', pattern_search_parameter)
      return [] if response['files'].nil? || response['files'].empty?

      # A typical response:
      # {
      #  "repoUri"=>"https:<artifactory endpoint>/<repo>",
      #  "sourcePattern"=>"<repo>:<provided search pattern>",
      #  "files"=>[<filename that matched pattern>, ...]
      # }
      #
      # Inserting '/api/storage' before the repo makes the 'from_url' call work correctly.
      #
      repo_uri = response['repoUri']
      unless repo_uri.include?('/api/storage/')
        # rubocop:disable Style/PercentLiteralDelimiters
        repo_uri.sub!(%r(/#{params[:repo]}$), "/api/storage/#{params[:repo]}")
      end
      response['files'].map do |file_path|
        from_url("#{repo_uri}/#{file_path}", client: client)
      end
    end

    # This adds the `exact_match` option to artifactory search, and defaults it
    # to true. With `exact_match` set to `true` the artifact will only be
    # returned if the name in the download uri matches the name we're trying to
    # download
    def search(options = {})
      exact_match = options[:exact_match].nil? ? true : options[:exact_match]
      artifacts = super

      if exact_match
        artifacts.select! { |artifact| File.basename(artifact.download_uri) == options[:name] }
      end
      artifacts
    end

    # This adds the `name` option to artifactory checksum search. It defaults to
    # unset. If set, the artifact is only returned if the download uri matches
    # the passed name
    def checksum_search(options = {})
      artifacts = super
      if options[:name]
        artifacts.select! { |artifact| File.basename(artifact.download_uri) == options[:name] }
      end
      artifacts
    end
  end

  # needed to prepend class methods, see https://stackoverflow.com/questions/18683750/how-to-prepend-classmethods
  def self.prepended(base)
    class << base
      prepend ClassMethods
    end
  end
end

module Artifactory
  class Resource::Artifact
    # use prepend instead of monkeypatching so we can call `super`
    prepend ArtifactoryExtensions
  end
end
