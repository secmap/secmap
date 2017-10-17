#!/usr/bin/env ruby

require __dir__+'/../conf/secmap_conf.rb'
require __dir__+'/../lib/common.rb'
require __dir__+'/../lib/command.rb'
require __dir__+'/../lib/redis.rb'

class PushTask < Command

  def initialize(commandName)
    super(commandName)

    @redis = RedisWrapper.new
    @analyzer = @redis.get_analyzer
    if @analyzer == nil
      @analyzer = ANALYZER
    end
    @commandTable.append("addFile", 3, "push_file", ["Add file to task list.", "Usage: addFile <file path> <analyzer> <priority> .", "Analyzer can be all ."])
    @commandTable.append("addDir", 3, "push_dir", ["Add all files under directory to task list.", "Usage: addDir <dir path> <analyzer> <priority> .", "Analyzer can be all ."])
    @commandTable.append("addDirBase", 4, "push_dir_base", ["Add all files with some basename under directory to task list.", "Usage: addDir <dir path> <analyzer> <priority> <basename> .", "Analyzer can be all ."])
  end

  def push_file(filepath, analyzer, priority)
    file = File.absolute_path(filepath)
    push_to_redis(file, analyzer, priority)
    puts "#{taskuid}\t#{File.expand_path(filepath)}"
    return "#{taskuid}\t#{File.expand_path(filepath)}"
  end

  def push_to_redis(taskuid, analyzer, priority)
    if analyzer == 'all'
      @analyzer.each do |a|
        @redis.push_taskuid(taskuid, a, priority)
      end
    else
      @redis.push_taskuid(taskuid, analyzer, priority)
    end
  end

  def push_dir(dirpath, analyzer, priority)
    dirpath = File.expand_path(dirpath)

    Dir.glob("#{dirpath}/**/*/").push(dirpath).each do |d|
      Dir.glob("#{d}/*").each do |f|
        if !File.file?(f)
          next
        end
        file = File.absolute_path(f.strip)
        push_to_redis(file, analyzer, priority)
      end
    end
  end

end

if __FILE__ == $0
  PushTask.new($0).main
end
