#!/usr/bin/env ruby

require 'docker'
require __dir__+'/command.rb'

class DockerWrapper < Command

	def initialize
		@dockername = nil
		@dockerimage = nil
		@createOptions = {'Image' => @dockerimage, 'name' => @dockername}
	end

	def getImage
		if checkImage
			puts "#{@dockerimage} already exist"
			return
		end
		image = Docker::Image.create('fromImage' => @dockerimage)
		puts image
	end

	def checkImage
		return Docker::Image.exist?(@dockerimage)
	end

	def checkContainer
		exist = true
		begin
			Docker::Container.get(@dockername)
		rescue Docker::Error::NotFoundError
			exist = false
		end
		return exist
	end

	def createContainer
		if checkContainer
			puts "container #{@dockername} already exist"
			return
		end
		res = Docker::Container.create(@createOptions)
		puts res
	end

	def startContainer
		if infoContainer["State"]["Running"]
			puts "#{@dockername} is already running."
			return
		end
		begin
			container = Docker::Container.get(@dockername)
			container.start
		rescue Docker::Error::NotFoundError
			puts "#{@dockername} container not create yet."
		end
	end

	def stopContainer
		if !infoContainer["State"]["Running"]
			puts "#{@dockername} has been stopped."
			return
		end
		begin
			container = Docker::Container.get(@dockername)
			container.kill
			container.stop
		rescue Docker::Error::NotFoundError
			puts "#{@dockername} container not create yet."
		end
	end

	def statsContainer
		stats = nil
		begin
			container = Docker::Container.get(@dockername)
			stats = container.stats
		rescue Docker::Error::NotFoundError
			puts "#{@dockername} container not create yet."
		end
		return stats
	end

	def infoContainer
		info = nil
		begin
			container = Docker::Container.get(@dockername)
			info = container.json
		rescue Docker::Error::NotFoundError
			puts "#{@dockername} container not create yet."
		end
		return info
	end

	def main(pidfile=nil)
		errMsg = "usage: #{__FILE__} init/start/stop/status"
		if ARGV.length != 1
			puts errMsg
			exit
		end
		case ARGV[0]
		when 'init'
			getImage
			createContainer
		when 'start'
			startContainer
			if pidfile != nil
				`echo docker > #{pidfile}`
			end
		when 'stop'
			stopContainer
			if pidfile != nil
				`rm #{pidfile}`
			end
		when 'restart'
			stopContainer
			startContainer
			if pidfile != nil
				`echo docker > #{pidfile}`
			end
		when 'status'
			puts "running ? " + infoContainer["State"]["Running"].to_s
		else
			puts errMsg
		end
	end
end
