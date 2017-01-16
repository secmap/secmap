#!/usr/bin/env ruby

require __dir__+'/../conf/secmap_conf.rb'
require __dir__+'/../lib/common.rb'
require __dir__+'/../lib/command.rb'
require __dir__+'/../lib/cassandra.rb'
require __dir__+'/../lib/redis.rb'

class PushTask < Command

	def initialize(commandName)
		super(commandName)

		@cassandra = CassandraWrapper.new(CASSANDRA)
		@redis = RedisWrapper.new
		@analyzer = @redis.get_analyzer
		if @analyzer == nil
			@analyzer = ANALYZER
		end
		@commandTable.append("addFile", 3, "push_file", ["Add file to task list.", "Usage: addFile <file path> <analyzer> <priority> .", "Analyzer can be all ."])
		@commandTable.append("addDir", 3, "push_dir", ["Add all files under directory to task list.", "Usage: addDir <dir path> <analyzer> <priority> .", "Analyzer can be all ."])
	end

	def push_file(filepath, analyzer, priority)
		taskuid = @cassandra.insert_file(filepath)
		if taskuid == nil
			STDERR.puts "Insert file fail!!!!"
			return
		end
		push_to_redis(taskuid, analyzer, priority)
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

		if File.exist?("#{dirpath}/all_taskuid")
			lines = File.new("#{dirpath}/all_taskuid", 'r').readlines.each do |line|
				taskuid = line.gsub(/\t.*\n/, '')
				push_to_redis(taskuid, analyzer, priority)
			end
		else
			lines = ''
			Dir.glob("#{dirpath}/**/*", File::FNM_DOTMATCH).each do |f|
				if !File.file?(f)
					next
				end
				STDOUT.reopen('/dev/null')
				lines += push_file(f, analyzer, priority) + "\n"
				STDOUT.reopen($stdout)
			end
			File.new("#{dirpath}/all_taskuid", 'w').write(lines)
		end
	end

end

if __FILE__ == $0
	PushTask.new($0).main
end
