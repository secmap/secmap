#!/usr/bin/env ruby

require 'etc'
require __dir__+'/../lib/redis.rb'
require __dir__+'/../lib/analyze.rb'

class Cpu
  attr_accessor :user, :nice, :system, :idle, :iowait, :irq, :softirq, :steal, :guest, :guest_nice, :total

  def initialize
    stat = File.open('/proc/stat', 'r').readline.strip.split
    @user = stat[1].to_f
    @nice = stat[2].to_f
    @system = stat[3].to_f
    @idle = stat[4].to_f
    @iowait = stat[5].to_f
    @irq = stat[6].to_f
    @softirq = stat[7].to_f
    @steal = stat[8].to_f
    @guest = stat[9].to_f
    @guest_nice = stat[10].to_f
    @total = @user + @nice + @system + @idle + @iowait + @irq + @softirq + @steal + @guest + @guest_nice
  end

  def - (item)
    new = self.clone
    new.user -= item.user
    new.nice -= item.nice
    new.system -= item.system
    new.idle -= item.idle
    new.iowait -= item.iowait
    new.irq -= item.irq
    new.softirq -= item.softirq
    new.steal -= item.steal
    new.guest -= item.guest
    new.guest_nice -= item.guest_nice
    new.total -= item.total
    return new
  end

  def usage
    return (@user + @nice + @system) / @total * 100
  end
end

def fork_analyzer
  pid = fork do
    Analyze.new(ENV['analyzer']).do
  end
  return pid
end

def cpu_usage
  a = Cpu.new
  sleep 0.1
  return (Cpu.new - a).usage
end

def kill_all(pids)
  pids.each do |pid|
    Process.kill('INT', pid)
  end
  pids.each do |pid|
    Process.join(pid)
  end
end

if __FILE__ == $0
  r = RedisWrapper.new()
  pids = []
  while true
    if r.exist(ENV['analyzer'])
      if pids.length >= Etc.nprocessors
          sleep(1)
      else
        if cpu_usage < 99.0
          pids << fork_analyzer
          STDERR.puts("Num of #{ENV['analyzer']}: #{pids.length}")
        end
      end
    else
      kill_all(pids)
    end
  end
end

