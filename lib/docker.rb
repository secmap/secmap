#!/usr/bin/env ruby

require 'docker'
require __dir__+'/command.rb'

class DockerWrapper < Command

  def initialize(commandName="dockerTemplate", dockerName="", dockerImage="", buildDir="")
    super(commandName)
    @dockerName = dockerName
    @dockerImage = dockerImage
    @buildDir = buildDir
    @createOptions = {'Image' => @dockerImage, 'name' => @dockerName}

    @commandTable.append("pull", 0, "pullImage", ["Pull image #{@dockerImage}."])
    @commandTable.append("build", 0, "buildImage", ["Build #{@dockerImage} by Dockerfile."])
    @commandTable.append("rmi", 0, "removeImage", ["Remove image #{@dockerImage}."])
    @commandTable.append("create", 0, "createContainer", ["Create #{@dockerName} container from #{@dockerImage}."])
    @commandTable.append("rm", 0, "removeContainer", ["Remove #{@dockerName} container."])
    @commandTable.append("start", 0, "startContainer", ["Start #{@dockerName}."])
    @commandTable.append("stop", 0, "stopContainer", ["Stop #{@dockerName}."])
    @commandTable.append("restart", 0, "restartContainer", ["Retart #{@dockerName}."])
    @commandTable.append("status", 0, "status", ["Show #{@dockerName} status."])
    @commandTable.append("ps", 0, "ps", ["Show all container."])
    @commandTable.append("logs", 0, "logs", ["Show logs."])
  end

  def pullImage
    if checkImage
      puts "Image #{@dockerImage} already exist."
      return
    end
    Excon.defaults[:read_timeout] = 1000
    Excon.defaults[:write_timeout] = 1000
    image = Docker::Image.create('fromImage' => @dockerImage)
    puts image
  end

  def buildImage
    if checkImage
      puts "Image #{@dockerImage} already exist."
      return
    end
    if File.exist?(@buildDir+'/Dockerfile')
      Excon.defaults[:read_timeout] = 1000
      Excon.defaults[:write_timeout] = 1000
      image = Docker::Image.build_from_dir(@buildDir)
      image.tag('repo' => @dockerImage.split(':')[0], 'tag' => @dockerImage.split(':')[1], force: true)
    else
      puts "Dockerfile of #{@dockerImage} not found."
    end
  end

  def removeImage
    if !checkImage
            puts "Image #{@dockerImage} doesn't exist."
            return
        end
    image = Docker::Image.get(@dockerImage)
    image.remove(:force => true)
  end

  def checkImage
    return Docker::Image.exist?(@dockerImage)
  end

  def checkContainer
    exist = true
    begin
      Docker::Container.get(@dockerName)
    rescue Docker::Error::NotFoundError
      exist = false
    end
    return exist
  end

  def createContainer
    if checkContainer
      puts "Container #{@dockerName} already exist."
      return
    end
    res = Docker::Container.create(@createOptions)
    @dockerName = res.id
    puts res.id
  end

  def removeContainer
    if !checkContainer
            puts "Container #{@dockerName} doesn't exist."
            return
        end
    container = Docker::Container.get(@dockerName)
    container.delete(:force => true)
  end

  def startContainer
    if !checkContainer
      puts "Container #{@dockerName} doesn't exist.\nPlease create container first."
      return
    end
    if infoContainer["State"]["Running"]
      puts "#{@dockerName} is already running."
      return
    end
    begin
      container = Docker::Container.get(@dockerName)
      container.start
    rescue Docker::Error::NotFoundError
      puts "#{@dockerName} container not create yet."
    end
  end

  def stopContainer
    if !infoContainer["State"]["Running"]
      puts "#{@dockerName} has been stopped."
      return
    end
    begin
      container = Docker::Container.get(@dockerName)
      container.kill
      container.stop
    rescue Docker::Error::NotFoundError
      puts "#{@dockerName} container not create yet."
    end
  end

  def restartContainer
    stopContainer
    startContainer
  end

  def status
    if checkImage
      puts "Image #{@dockerImage} exist."
      if checkContainer
        puts "Container #{@dockerName} exist."
        if infoContainer["State"]["Running"]
          puts "Container #{@dockerName} running."
        else
          puts "Container #{@dockerName} stopped."
        end
      else
        puts "Container #{@dockerName} doesn't exist."
      end
    else
      puts "Image #{@dockerImage} doesn't exist."
    end
  end

  def statsContainer
    stats = nil
    begin
      container = Docker::Container.get(@dockerName)
      stats = container.stats
    rescue Docker::Error::NotFoundError
      puts "#{@dockerName} container not create yet."
    end
    return stats
  end

  def infoContainer
    info = nil
    begin
      container = Docker::Container.get(@dockerName)
      info = container.json
    rescue Docker::Error::NotFoundError
      puts "#{@dockerName} container not create yet."
    end
    return info
  end

  def exec(*cmd)
    Docker::Container.get(@dockerName).exec(*cmd)
  end

  def ps
    infos = []
    Docker::Container.all(:all => true).each do |a|
      infos.push(a.info)
    end
    return infos
  end

  def logs
    logs = ''
    begin
      container = Docker::Container.get(@dockerName)
      logs = container.logs(stdout: true, stderr: true)
    rescue Docker::Error::NotFoundError
      puts "#{@dockerName} container not create yet."
    end
    return logs
  end

end
