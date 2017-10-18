#!/usr/bin/env ruby

require __dir__+'/../lib/docker.rb'

class RedisDocker < DockerWrapper

  def initialize(commandName)
    super(commandName, "secmap-redis", "redis:3.2.6", __dir__)

    @createOptions = {
      'Image' => @dockerImage,
      'name' => @dockerName,
      'HostConfig' => {
        'PortBindings' => {
          '6379/tcp' => [{ 'HostPort' => '6379' }]
        }
      }
    }
  end
end

if  __FILE__ == $0
  RedisDocker.new($0).main
end
