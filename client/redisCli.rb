#!/usr/bin/env ruby

require 'redis'
require __dir__+'/../conf/secmap_conf.rb'
require __dir__+'/../lib/command.rb'
require __dir__+'/../lib/redis.rb'

class RedisCli < Command

  def initialize(commandName)
    super(commandName)

    @commandTable.append("init", 0, "init_redis", ["Initialize redis data."])
    @commandTable.append("reload", 0, "reload_redis", ["Reload redis data."])
    @commandTable.append("status", 0, "status", ["Show redis status."])
    @commandTable.append("wait", 0, "wait_done", ["Wait all task done."])
  end

  def init_redis
    r = RedisWrapper.new
    r.init_redis
  end

  def reload_redis
    r = RedisWrapper.new
    r.reload_redis
  end

  def status
    r = RedisWrapper.new
    puts "Running ? #{r.status.to_s}"
  end

  def wait_done
    r = RedisWrapper.new
    r.wait_done
  end

end

if __FILE__ == $0
  r = RedisCli.new($0)
  r.main
end
