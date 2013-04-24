if @build.build_pe
  namespace :pe do
    namespace :jenkins do

      # build_and_wait is NOT reentrant. The right thing to do is
      # generate some sort of unique identifier and pass that through
      # the builds, but that will require some additional work on the
      # jenkins job interface. For now, just don't call build_and_wait
      # on the same SHA while a build is running.
      task :build_and_wait do
        require 'dalli'
        fail "Must set MEMCACHE_SERVER" unless ENV['MEMCACHE_SERVER']
        dc = Dalli::Client.new(ENV['MEMCACHE_SERVER'])
        dc.delete(git_sha)
        invoke_task("pe:jenkins:uber_build")
        count = dc.get(git_sha).to_i
        start_time = Time.now
        until count == 3 do
          count = dc.get(git_sha).to_i
          if Time.now - start_time > 600 # 10 minutes
            fail "Expected all our build jobs to check in by now. Something's screwed"
          end
          sleep 5 # so we don't totally spam memcached
        end
      end

      task :build_complete do
        require 'dalli'
        fail "Must set MEMCACHE_SERVER" unless ENV['MEMCACHE_SERVER']
        dc = Dalli::Client.new(ENV['MEMCACHE_SERVER'])
        dc.incr(git_sha, 1, 86400, 1)
      end
    end
  end
end
