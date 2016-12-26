require 'rubygems'
require 'find'

class PropertyLoader
   def initialize(filename)
     @filename = filename
     @properties = {} 
     load_properties()
   end
   
   def load_properties()
    File.open(@filename, 'r') do |properties_file|
      properties_file.read.each_line do |line|
        line.strip!
        if (line[0] != ?# and line[0] != ?=)
          i = line.index('=')
          if (i)
            @properties[line[0..i - 1].strip] = line[i + 1..-1].strip
          else
            @properties[line] = ''
          end
        end
      end
    end
    #@properties.each {|k,v| puts "#{k}=#{v}"}
   end
  
   def getPro(proname)
       return @properties[proname]
   end

   def appendValue(pattern,value)
   	File.open(@filename, "r+") do |properties_file|
	   out = ""
      	   properties_file.read.each_line do |line|
	      out << line.gsub(/#{pattern}.*/){line.strip + " " + value}
           end
	   properties_file.pos = 0                     
    	   properties_file.print out
	   properties_file.truncate(properties_file.pos)  
        end
   end
 
end

