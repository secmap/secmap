#!/usr/bin/env ruby

require 'etc'
require __dir__+'/../conf/secmap_conf.rb'
require __dir__+'/cassandra.rb'
require __dir__+'/redis.rb'

class Analyze

  def initialize(analyzer_name)
    @priority = [0, 1, 2, 3]
    @analyzer_name = analyzer_name
    @sleep_seconds = 5
    @clk_tck = Etc.sysconf(Etc::SC_CLK_TCK)
    @np = Etc.nprocessors

    @redis = RedisWrapper.new
    @cassandra = CassandraWrapper.new(CASSANDRA)
    @log = File.new("/log/#{@analyzer_name}.log", 'a')
  end

  def get_file
    file = nil
    while file == nil
      @priority.each do |p|
        file = @redis.get_taskuid("#{@analyzer_name}:#{p.to_s}")
        if file != nil
          @redis.set_doing(@analyzer_name)
          break
        end
      end
      if file == nil
        sleep(@sleep_seconds)
      end
    end
    return file
  end

  def analyze(file_path)
    result = ""
    max_memory = 0
    max_cpu = 0.0
    last_totaltime = 0
    last_cputime = 0
    start_time = 0
    IO.popen("/analyze #{file_path}", "r+") { |f|
      user, nice, system, idle, iowait, irq, softirq, steal = File.open("/proc/stat",'r').readline.split(' ')[1..8]
      start_time = user.to_i + nice.to_i + system.to_i + idle.to_i + iowait.to_i + irq.to_i + softirq.to_i + steal.to_i
      while true
        begin
          user, nice, system, idle, iowait, irq, softirq, steal = File.open("/proc/stat",'r').readline.split(' ')[1..8]
          utime, stime = File.open("/proc/#{f.pid}/stat",'r').read.strip.split(' ')[13..14]
          totaltime = user.to_i + nice.to_i + system.to_i + idle.to_i + iowait.to_i + irq.to_i + softirq.to_i + steal.to_i
          cputime = utime.to_i + stime.to_i
          cpu = (cputime - last_cputime) * 10000 / (totaltime - last_totaltime) / 100.0
          max_cpu = [cpu, max_cpu].max
          last_cputime = cputime
          last_totaltime = totaltime
          vmpeak = File.open("/proc/#{f.pid}/status",'r').read.match(/VmPeak:\s+([0-9]+)/)
          if vmpeak != nil
            max_memory = [vmpeak.captures[0].to_i, max_memory].max
          end
          while true
            result += f.read_nonblock(1024*1024*1024)
          end
        rescue IO::WaitReadable
          sleep 1
          next
        rescue EOFError
          break
        end
      end
    }
    begin
      report = JSON.parse(result)
    rescue JSON::ParserError
      report = {'stat' => 'error', 'messagetype' => 'string', 'message' => 'Analyzer error'}
      @redis.set_error(@analyzer_name)
      @redis.del_doing(@analyzer_name)
      result = nil
    end
    if report['stat'] == 'error'
      @log.write("#{file_path}:#{max_memory}:#{max_cpu*@np}:#{(last_totaltime - start_time)*100/@clk_tck/100.0/@np}:#{report['message']}:")
    else
      @log.write("#{file_path}:#{max_memory}:#{max_cpu*@np}:#{(last_totaltime - start_time)*100/@clk_tck/100.0/@np}:success:")
    end
    return result
  end

  def save_report(taskuid, report)
    res = @cassandra.insert_report(taskuid, report, @analyzer_name)
    if res == 'timeout'
      while res == 'timeout'
        STDERR.puts "#{taskuid} timeout!!!!"
        sleep Random.rand(10..30)
        res = @cassandra.insert_report(taskuid, report, @analyzer_name)
      end
    elsif res == false
      @log.write('db_error:')
    else
      @redis.del_doing(@analyzer_name)
      @log.write('db_success:')
    end
  end

  def do
    while true
      start = Time.now
      file = nil
      file = get_file
      if file == nil
        next
      end
      report = analyze(file)
      if report == nil
        @log.write('db_no_store:')
      else
        save_report(file, report)
      end
      @log.write("#{Time.now - start}\n")
      @log.flush
    end
  end

end
