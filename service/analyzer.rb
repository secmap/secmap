#!/usr/bin/env ruby

require __dir__+'/../lib/analyze.rb'
require __dir__+'/../lib/command.rb'
require __dir__+'/../lib/docker.rb'
require __dir__+'/../lib/analyzerDocker.rb'

class Analyzer < Command

  def initialize(commandName)
    super(commandName)
    
    @commandTable.append("set", 2, "set", ["Set analyze number.", "Usage: set <analyzer docker image name> <number of analyze> .", "Analyzer docker name can be all."])
    @commandTable.append("exist", 0, "printexist", ["Show all exist analyzer docker create by secmap."])
    @commandTable.append("update", 1, "update", ["Update analyzer.", "Usage: update <analyzer docker image name> ."])
    @commandTable.append("show", 0, "show", ["Show all analyzer image name."])
    @commandTable.append("logs", 1, "logs", ["Show analyzer logs.", "Usage: logs <analyzer docker image name> .", "Analyzer docker name can be all."])
  end

  def set(dockerImage, num)
    num = num.to_i
    existed = []

    exist.each do |a|
      if a[1] == dockerImage
        existed.push(a)
      end
    end

    while existed.length > num
      Docker::Container.get(existed.pop[0]).delete(:force => true)
    end

    STDOUT.reopen('/dev/null')
    (existed.length+1..num).each do |n|
      puts dockerImage, dockerImage.class
      AnalyzerDocker.new(dockerImage).startAnalyze
    end
    STDOUT.reopen($stdout)
    puts '123'
    existed.each do |a|
      Docker::Container.get(a[0]).start
    end
  end

  def exist
    existed = []

    DockerWrapper.new.ps.each do |info|
      type = info['Labels']['secmap']
      if type != nil
        existed.push([info['Names'][0], type, info['Status']])
      end
    end

    return existed
  end

  def printexist
    puts "Name\t\t\t\tType\t\t\t\tStatus"
    exist.each do |a|
      puts a * "\t\t\t\t"
    end
  end

  def update(dockerImage)
    num = num.to_i
    existed = []

    exist.each do |a|
      if a[1] == dockerImage
        docker = Docker::Container.get(a[0])
        docker.stop
        docker.delete(:force => true)
      end
    end

    image = AnalyzerDocker.new(dockerImage)
    image.removeImage
    image.pullImage
  end

  def show
    puts ANALYZER * ' '
  end

  def logs(dockerImage)
    existed = []

    if dockerImage == 'all'
      existed = exist
    else
      exist.each do |a|
        if a[1] == dockerImage
          existed.push(a)
        end
      end
    end

    existed.each do |a|
      puts a
      puts Docker::Container.get(a[0]).logs(stdout: true, stderr: true)
    end
  end

end

if __FILE__ == $0
  a = Analyzer.new($0).main
end
