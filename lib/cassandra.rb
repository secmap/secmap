#!/usr/bin/env ruby

require 'cassandra'
require 'socket'
require 'zlib'
require 'json'
require 'csv'
require __dir__+'/../conf/secmap_conf.rb'
require __dir__+'/common.rb'
require __dir__+'/redis.rb'
require __dir__+'/../client/pushTask.rb'

class CassandraWrapper

  def initialize(ip)
    begin
      @cluster = Cassandra.cluster(hosts: ip)
      @session = @cluster.connect
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot connect to cassandra cluster host on #{ip.to_s}."
      exit
    end

  end

  def available_host
    host = nil
    begin
      host = @cluster.each_host
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot get hosts."
    end
    return @cluster.each_host
  end

  def init_cassandra
    begin
      if @cluster.keyspace(KEYSPACE) == nil
        create_secmap
        create_summary
        analyzers = RedisWrapper.new.get_analyzer
        if analyzers == nil
          analyzers = ANALYZER
        end
        analyzers.each do |analyzer|
          create_analyzer(analyzer)
        end
      end
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot init database."
    end
  end

  def create_secmap
    secmap_definition = <<-KEYSPACE_CQL
      CREATE KEYSPACE #{KEYSPACE}
      WITH replication = {
        'class': 'SimpleStrategy',
        'replication_factor': #{REPLICA}
      }
    KEYSPACE_CQL
    begin
      @session.execute(secmap_definition)
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot create keyspace."
    end
  end

  def create_summary
    table_definition = <<-TABLE_CQL
      CREATE TABLE #{KEYSPACE}.SUMMARY (
        taskuid varchar,
        path set<varchar>,
        PRIMARY KEY (taskuid)
      )
    TABLE_CQL
    begin
      @session.execute(table_definition)
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot create summary table."
    end
  end

  def create_dataset
    table_definition = <<-TABLE_CQL
      CREATE TABLE #{KEYSPACE}.DATASET (
        dataset varchar,
        taskuid varchar,
        path varchar,
        label varchar,
        PRIMARY KEY (dataset, taskuid)
      )
    TABLE_CQL
    begin
      @session.execute(table_definition)
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot create dataset table."
    end
  end

  def create_msdataset
    table_definition = <<-TABLE_CQL
      CREATE TABLE #{KEYSPACE}.MSDATASET (
        dataset varchar,
        sample varchar,
        asm_taskuid varchar,
        bytes_taskuid varchar,
        label varchar,
        PRIMARY KEY (dataset, sample)
      )
    TABLE_CQL
    begin
      @session.execute(table_definition)
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot create dataset table."
    end
  end

  def create_analyzer(analyzer)
    table_definition = <<-TABLE_CQL
      CREATE TABLE #{KEYSPACE}.#{analyzer} (
        taskuid varchar PRIMARY KEY,
        overall blob,
        analyzer varchar,
        file boolean,
        analyze_time timeuuid
      )
    TABLE_CQL
    begin
      @session.execute(table_definition)
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot create analyzer table."
    end
  end

  def drop_table(table)
    table_definition = <<-TABLE_CQL
      DROP TABLE #{KEYSPACE}.#{table} 
    TABLE_CQL
    begin
      @session.execute(table_definition)
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot drop analyzer table."
    end
  end

  def list_tables
    tables = []
    begin
      @cluster.keyspace('secmap').each_table do |table|
        tables.push(table.name)
      end
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Cannot get all tables."
    end
    return tables
  end

  def parse_dataset_csv(csv, dir)
    result = []
    CSV.foreach(csv) do |file, label|
      result << [File.expand_path("#{dir}/#{file}"), label]
    end
    return result[1..-1]
  end

  def import_dataset(dataset, csv, dir)
    if !File.exist?("#{dir}/all_taskuid")
      p "no all_taskuid"
      PushTask.new("").create_all_taskuid(dir)
    end
    labels = parse_dataset_csv(csv, dir)
    taskuid_hash = {}
    File.open("#{dir}/all_taskuid").readlines.each do |line|
      taskuid, file = line.strip.split("\t")
      taskuid_hash[file] = taskuid
    end
    labels.each do |label|
      label << taskuid_hash[label[0]]
    end
    begin
      statement = @session.prepare("INSERT INTO #{KEYSPACE}.dataset (dataset, path, label, taskuid) VALUES (?, ?, ?, ?)")
      batch = @session.batch do |b|
        labels.each do |label|
          b.add(statement, arguments: [dataset, label[0], label[1], label[2]])
        end
      end
      @session.execute(batch)
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "import csv error!!!!"
    end
  end

  def parse_msdataset_csv(csv, dir)
    result = []
    CSV.foreach(csv) do |file, label|
      result << [file, File.expand_path("#{dir}/#{file}.asm"), File.expand_path("#{dir}/#{file}.bytes"), label]
    end
    return result[1..-1]
  end

  def import_msdataset(dataset, csv, dir)
    if !File.exist?("#{dir}/all_taskuid")
      p "no all_taskuid"
      PushTask.new("").create_all_taskuid(dir)
    end
    labels = parse_msdataset_csv(csv, dir)
    taskuid_hash = {}
    File.open("#{dir}/all_taskuid").readlines.each do |line|
      taskuid, file = line.strip.split("\t")
      taskuid_hash[file] = taskuid
    end
    labels.each do |label|
      label[1] = taskuid_hash[label[1]]
      label[2] = taskuid_hash[label[2]]
    end
    begin
      statement = @session.prepare("INSERT INTO #{KEYSPACE}.msdataset (dataset, sample, asm_taskuid, bytes_taskuid, label) VALUES (?, ?, ?, ?, ?)")
      batch = @session.batch do |b|
        labels.each do |label|
          b.add(statement, arguments: [dataset, label[0], label[1], label[2], label[3]])
        end
      end
      @session.execute(batch)
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "import csv error!!!!"
    end
  end

  def insert_file(file)
    begin
      statement = @session.prepare("INSERT INTO #{KEYSPACE}.summary (taskuid, path) VALUES (?, ?) IF NOT EXISTS")
      taskuid = generateSecmapUID(file)
      path = File.expand_path(file)
      result = @session.execute(statement, arguments: [taskuid, Set[path]], timeout: 3)
      if !result.first["[applied]"]
        puts "existed"
        statement = @session.prepare("UPDATE #{KEYSPACE}.summary SET path = path + ? WHERE taskuid = ?")
        result = @session.execute(statement, arguments: [Set[path], taskuid], timeout: 3)
      end
    rescue TimeoutError => e
      STDERR.puts e.message
      STDERR.puts file+" timeout!!!!!!"
      taskuid = 'timeout'
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts file+" error!!!!!!"
      taskuid = nil
    end
    return taskuid
  end

  def get_file(taskuid)
    r = nil
    begin
      statement = @session.prepare("SELECT * FROM #{KEYSPACE}.summary WHERE taskuid = ? ")
      rows = @session.execute(statement, arguments: [taskuid], timeout: 3)
      rows.each do |row|
        r = row
        break
      end
    rescue TimeoutError => e
      STDERR.puts e.message
      STDERR.puts "Get file #{taskuid} timeout!!!!!!"
      r = 'timeout'
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Get file #{taskuid} error!!!!!!"
    end
    return r
  end

  def insert_report(taskuid, report, analyzer)
    result = false
    begin
      host = Socket.gethostname
      generator = Cassandra::Uuid::Generator.new
      compressed_report = Zlib::Deflate.deflate(report.strip, Zlib::BEST_COMPRESSION)
      statement = @session.prepare("INSERT INTO #{KEYSPACE}.#{analyzer} (taskuid, overall, analyzer, file, analyze_time) VALUES (?, ?, ?, ?, ?)")
      if compressed_report.length >= 1 * 1024 * 1024
        report_path = "#{REPORT}/#{analyzer}/#{taskuid}"
        File.open(report_path, 'wb').write(compressed_report)
        @session.execute(statement, arguments: [taskuid, report_path, "#{analyzer}@#{host}", true, generator.now], timeout: 3)
      else
        @session.execute(statement, arguments: [taskuid, compressed_report, "#{analyzer}@#{host}", false, generator.now], timeout: 3)
      end
      result = true
    rescue TimeoutError => e
      STDERR.puts e.message
      STDERR.puts taskuid+" timeout!!!!!!"
      result = 'timeout'
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts taskuid+" error!!!!!!"
    end
    return result
  end

  def get_report(taskuid, analyzer)
    r = nil
    begin
      statement = @session.prepare("SELECT * FROM #{KEYSPACE}.#{analyzer} WHERE taskuid = ?")
      rows = @session.execute(statement, arguments: [taskuid], timeout: 3)
      r = rows.each.first
      if r['file'] == true
        r['overall'] = File.open(r['overall'], 'rb').read
      end
      r['overall'] = Zlib::Inflate.inflate(r['overall']).strip
    rescue TimeoutError => e
      STDERR.puts e.message
      STDERR.puts "Get report #{taskuid} timeout!!!!!!"
      r = 'timeout'
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Get report #{taskuid} error!!!!!!"
    end
    return r
  end

  def get_all_report(analyzer)
    report = ""
    begin
      statement = @session.prepare("SELECT * FROM #{KEYSPACE}.#{analyzer}")
      rows = @session.execute(statement, timeout: 3)
      rows.each do |row|
        if row['file'] == true
          row['overall'] = File.open(row['overall'], 'rb').read
        end
        row['overall'] = Zlib::Inflate.inflate(row['overall']).strip
        report += "#{row['taskuid']}\t#{row['overall']}\t#{row['analyzer']}\t#{row['analyze_time'].to_time.localtime.to_s}\n"
      end
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts "Get all report error!!!!!!"
    end
    return report
  end

  def parse_record(row)
    if row['file'] == true
      row['overall'] = File.open(row['overall'], 'rb').read
    end
    overall = Zlib::Inflate.inflate(row['overall']).strip
    if overall.empty?
      puts row.inspect
      raise "Empty overall found for taskuid: #{row['taskuid']}"
    end
    record = overall
    record = JSON.parse(record)
    return record
  end

  def create_csv_header(analyzers)
    analyzers_feature_num = {}
    analyzers.each do |analyzer|
      statement = @session.prepare("SELECT * FROM #{KEYSPACE}.#{analyzer} LIMIT 1")
      @session.execute(statement, timeout: 3).each do |row|
        record = parse_record(row)
        if record['stat'] == 'success' && record['messagetype'] == 'list'
          num_features = record['message'].length
          analyzers_feature_num[analyzer] = num_features
        end
      end
    end

    csv_header = []
    analyzers_feature_num.each do |analyzer, feature_num|
      (0..feature_num-1).each do |i|
        csv_header << "#{analyzer}(#{i})"
      end
    end
    return csv_header
  end
  
  def get_all_report_to_csv(filename)
    tables = list_tables()
    # Remove tables that are not a analyze table
    # analyzers = tables - ['summary', 'dataset', 'api_bin']
    analyzers_feature_num = []

    analyzers_asm = ['register_asm', 'md2_asm', 'opcode_asm', 'api_asm', 'dp_asm', 'sym_asm', 'misc_asm', 'section_asm']
    analyzers_bytes = ['img1_bytes', 'bytes_2_gram', 'bytes_1_gram', 'md1_bytes', 'entropy_bytes', 'img2_bytes']

    begin
      CSV.open(filename, 'wb') do |csv|
        # First construct csv header
        csv_header = create_csv_header(analyzers_bytes + analyzers_asm)
        csv << (csv_header << "label")

        # Second, deal with features
        statement = @session.prepare("SELECT asm_taskuid,bytes_taskuid,label FROM #{KEYSPACE}.msdataset")
        @session.execute(statement, timeout: 3).each do |sample|
          asm_taskuid = sample['asm_taskuid']
          bytes_taskuid = sample['bytes_taskuid']
          label = sample['label']

          features = []
          success = true
          analyzers_asm.each do |analyzer|
            row_stmt = @session.prepare("SELECT * FROM #{KEYSPACE}.#{analyzer} WHERE taskuid = ?")
            rows = @session.execute(row_stmt, arguments: [asm_taskuid], timeout: 3)
            if rows.length > 1
              raise "Found more than one record for asm_taskuid: #{taskuid}"
            elsif rows.length == 0
              puts "Cannot found record for asm_taskuid: #{taskuid} in analyzer: #{analyzer}."
              success = false
              break
            end

            row = rows.first
            
            begin
              record = parse_record(row)
            rescue
              puts "Parse record failed for #{row['taskuid']}"
              success = false
              next
            end

            if record['stat'] == 'success' && record['messagetype'] == 'list'
              raise "List required but #{record['message'].class} found." if record['message'].class != Array
              features += record['message']
            elsif
              puts "Either stat not success or messagetype not list for taskuid: #{asm_taskuid} in analyzer: #{analyzer}."
              success = false
            end
          end

          if success == false
            #next
          end

          analyzers_bytes.each do |analyzer|
            row_stmt = @session.prepare("SELECT * FROM #{KEYSPACE}.#{analyzer} WHERE taskuid = ?")
            rows = @session.execute(row_stmt, arguments: [bytes_taskuid], timeout: 3)
            if rows.length > 1
              raise "Found more than one record for bytes_taskuid: #{taskuid}"
            elsif rows.length == 0
              puts "Cannot found record for bytes_taskuid: #{bytes_taskuid} in analyzer: #{analyzer}."
              success = false
              break
            end

            row = rows.first
            
            begin
              record = parse_record(row)
            rescue
              puts "Parse record failed for #{row['taskuid']}"
              success = false
              next 
            end

            if record['stat'] == 'success' && record['messagetype'] == 'list'
              raise "List required but #{record['message'].class} found." if record['message'].class != Array
              features += record['message']
            elsif
              puts "Either stat not success or messagetype not list for taskuid: #{taskuid} in analyzer: #{analyzer}."
              success = false
            end
          end
          
          if success
            csv << (features << label)
          end
        end
      end
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts e.backtrace
      STDERR.puts "Get all report error!!!!!!"
    end
  end

  def select_feature_from(filename, analyzers, output_filename)
    CSV.open(output_filename, 'wb') do |csv|
      CSV.foreach(filename, headers: true) do |row|
        filtered_row = []
        row.each do |feature_name, value|
          if feature_name == 'label'
            filtered_row << value
          else
            feature_analyzer = /(.*)\(\d+\)/.match(feature_name)[1]
            if analyzers.include? feature_analyzer
              filtered_row << value
            end
          end
        end
        csv << filtered_row
      end
    end
  end

  def close
    @session.close
    @cluster.close
  end

end
