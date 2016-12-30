#!/usr/bin/env ruby

require 'sys/filesystem'
require 'socket'
require __dir__+'/../conf/secmap_conf.rb'
require __dir__+'/../lib/docker.rb'

class CassandraDocker < DockerWrapper

	def initialize
		@dockername = "secmap-cassandra"
		@dockerimage = "cassandra:3.9"

		tokens = (Sys::Filesystem.stat('/').block_size * Sys::Filesystem.stat('/').blocks_available / 1024.0 / 1024.0 / 1024.0 / 1024.0 * 256).to_i
		hostIP = nil
		Socket.ip_address_list.each do |ip|
			if ip.ip_address.index('192.168.') != nil
				hostIP = ip.ip_address
				break
			end
		end

		@createOptions = {
		  'Image' => @dockerimage,
		  'name' => @dockername,
		  'Volumes' => { '/var/lib/cassandra' => {} },
		  'ENV' => [
		    "CASSANDRA_CLUSTER_NAME='SECMAP Cluster'",
		    "CASSANDRA_NUM_TOKENS=#{tokens}",
		    #"CASSANDRA_SEEDS=#{CASSANDRA * ' '}",
		    "CASSANDRA_BROADCAST_ADDRESS=#{hostIP}"
		  ],
		  'HostConfig' => {
		    'Binds' => ["#{DATA_HOME}:/var/lib/cassandra"],
		    'PortBindings' => {
		      '7000/tcp' => [{ 'HostPort' => '7000' }],
		      '7001/tcp' => [{ 'HostPort' => '7001' }],
		      '7199/tcp' => [{ 'HostPort' => '7199' }],
		      '9042/tcp' => [{ 'HostPort' => '9042' }],
		      '9160/tcp' => [{ 'HostPort' => '9160' }]
		    }
		  }
		}
	end
end

if  __FILE__ == $0
	c = CassandraDocker.new
	c.main(__dir__+'/../storage/cassandra.pid')
end