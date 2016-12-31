#!/usr/bin/env ruby

require 'redis'
require __dir__+'/../conf/secmap_conf.rb'
require LIB_HOME+'/command.rb'
require LIB_HOME+'/redis.rb'

class RedisCli < Command

	def initialize(commandName, prefix)
		super(commandName, prefix)

		@commandTable.append("init", 0, "init_redis", ["Initialize redis data."])
		@commandTable.append("status", 0, "status", ["Show redis status."])
	end

	def init_redis
		r = RedisWrapper.new
		r.init_redis
	end

	def status
		r = RedisWrapper.new
		puts "Running ? #{r.status.to_s}"
	end

end

if __FILE__ == $0
	r = RedisCli.new($0, "")
	r.main
end
