#!/usr/bin/env ruby

# Store the IP of the redis node
# EX: REDIS_ADDR = '192.168.100.100'
REDIS_ADDR = ''
REDIS_PORT = 6379

# Store the IPs of cassandra seeds
# EX: CASSANDRA_SEEDS = ['192.168.100.1', '192.168.100.2', '192.168.100.3', ...]
CASSANDRA_SEEDS = ['']
# Store the IPs of cassandra nodes
# EX: CASSANDRA = ['192.168.100.1', '192.168.100.2', '192.168.100.3', ...]
CASSANDRA = ['']
# Store the port of cassandra
CASSANDRAPORT = 9042
REPLICA = 1

# Database keyspace
KEYSPACE = 'secmap'

# Store the analyzers
# EX: ANALYZER = ['MBA', 'CLAMAV', 'VirusTotal', 'FRNSR', 'Antivir' 'Kaspersky']
ANALYZER = ['']

# Docker account name
DOCKER = ''

# Sample directory
SAMPLE = ''

# Report directory
REPORT = ''

# Daily update sample directories
DAILY = ['']

# Only redis server have to config this
REDIS_INIT = {
  'CASSANDRA' => CASSANDRA * ' ',
  'CASSANDRAPORT' => CASSANDRAPORT,
  'KEYSPACE' => KEYSPACE,
  'ANALYZERS' => ANALYZER * ' ',
  'CLEAN_UP_TIME' => '420',  #7  MIN
  'FORCE_QUIT_TIME' => '600'  #10 MIN
}

