#!/usr/bin/env ruby

require 'redis'
require 'socket'
require __dir__+'/../conf/secmap_conf.rb'

class RedisWrapper

  def initialize
    begin
      @r = Redis.new(:host => REDIS_ADDR, :port => REDIS_PORT)
    rescue
      puts "redis server #{REDIS_ADDR} is not available."
    end
    @taskuid = nil
    @time = nil
    @host = Socket.gethostname
  end

  def init_redis
    begin
      @r.flushdb
      REDIS_INIT.each do |key, value|
        @r[key] = value
      end
    rescue Redis::CannotConnectError
      puts "Cannot connect to redis server #{REDIS_ADDR}."
    end
  end

  def reload_redis
    begin
      REDIS_INIT.each do |key, value|
        @r[key] = value
      end
    rescue Redis::CannotConnectError
      puts "Cannot connect to redis server #{REDIS_ADDR}."
    end
  end

  def status
    available = true
    begin
      @r.ping
    rescue
      available = false
    end
    return available
  end

  def get
    return @r
  end

  def get_taskuid(analyzer)
    @taskuid = nil
    begin
      @taskuid = @r.lpop(analyzer)
      @time = Time.new.to_s
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts 'Get taskuid fail!!!!'
      @taskuid = nil
    end
    return @taskuid
  end

  def set_doing(analyzer)
    begin
      @r.rpush("#{analyzer}:doing", "#{@taskuid}:#{@time}:#{@host}")
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts 'Set doing fail!!!!'
    end
  end

  def del_doing(analyzer)
    begin
      @r.lrem("#{analyzer}:doing" , 1, "#{@taskuid}:#{@time}:#{@host}")
      @taskuid = nil
      @time = nil
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts 'Set doing fail!!!!'
    end
  end

  def set_error(analyzer)
    begin
      @r.rpush("#{analyzer}:error", "#{@taskuid}:#{@time}:#{@host}")
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts 'Set doing fail!!!!'
    end
  end

  def push_taskuid(taskuid, analyzer, priority)
    begin
      @r.rpush("#{analyzer}:#{priority}", taskuid)
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts 'Push task fail!!!!'
    end
  end

  def wait_done
    while true
      done = true
      ANALYZER.each do |a|
        ['0', '1', '2', 'doing'].each do |p|
          begin
            if @r.exists("#{a}:#{p}")
              done = false
              sleep(1)
              break
            end
          rescue Exception => e
            STDERR.puts e.message
          end
        end
      end
      if done
        break
      end
    end
  end

  def get_analyzer
    analyzer = nil
    begin
      analyzer = @r.get('ANALYZERS').split(' ')
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts 'Get analyzer from fail!!!!'
      STDERR.puts 'Use local config.'
    end
    return analyzer
  end

end
