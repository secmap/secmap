#!/usr/bin/env ruby

require 'socket'
require __dir__+'/../conf/secmap_conf.rb'
require __dir__+'/docker.rb'
require __dir__+'/common.rb'

class AnalyzerDocker < DockerWrapper

  def initialize(dockerImage)
    @dockerImage = "#{DOCKER}/#{dockerImage}"
    @analyzerName = dockerImage
    super('', '', @dockerImage, __dir__)
    @dockerName = " "

    @createOptions = {
      'Image' => @dockerImage,
      'Hostname' => Socket.gethostname,
      'AttachStdin': true,
      'AttachStdout': true,
      'AttachStderr': true,
      'Tty': true,
      'Entrypoint' => '/secmap/analyzer/doAnalyze.rb',
      'Volumes' => { '/secmap' => {}, SAMPLE => {}, '/log' => {}, REPORT => {} },
      'Labels' => { 'secmap' => @analyzerName },
      'ENV' => ["analyzer=#{@analyzerName}"],
      'HostConfig' => {
        'Binds' => ["#{File.expand_path(__dir__+"/../")}:/secmap:ro", "#{SAMPLE}:#{SAMPLE}:ro", "#{File.expand_path(__dir__+"/../log")}:/log", "#{REPORT}:#{REPORT}"]
      }
    }
    createLogHome
  end

  def startAnalyze
    pullImage
    createContainer
    startContainer
  end

  def stopAnalyze
    stopContainer
  end

end
