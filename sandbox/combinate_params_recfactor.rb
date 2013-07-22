require 'pp'
require 'fileutils'
require 'csv'
require 'threach'

$SOAP_file_path = '/bio_apps/SOAPdenovo-Trans1.02/SOAPdenovo-Trans-127mer'


class ParameterSweeper
  def initialize(options, constructor)
    # constructor: commands to pass to soapdt
    @constructor = constructor
    # input_parameters: hash of options produced by user
    @input_parameters = options
    # parameter_counter: a count of input parameters to be used
    @parameter_counter = 1
    # input_combinations: an array of arrays of input parameters
    @input_combinations = []
    # options contains both the parameter sweep values and other soapdt options, we want to seperate these

    options.each do |key, value|
      if value.is_a? Array
        @input_parameters[key.to_sym] = (1..5).to_a
      else
        @input_parameters[key.to_sym] = [value]
      end
    end

  end

  def run(groupsize)
    Dir.chdir('outputdata_refactor') do
      # generate the combinations of parameters to be applied to soapdt, stored in @input_parameters
      generate_configfile
      generate_combinations
      puts "Will perform #{@parameter_counter} assemblies"
      CSV.open("filenameToParameters.csv", "w") do |csv|
        csv << ['assembly_id'] + @input_parameters.keys + ['time']
      end

      constructor = "#{$SOAP_file_path} all -s soapdt.config"
      temporary_parameters = {:o => 10}.merge!(@input_parameters)
      
      @input_combinations.each do |parr|
        parr.each do |v|
          constructor += " -#{temporary_parameters.keys.first.to_s} #{v}"
          temporary_parameters.delete(temporary_parameters.keys.first)

        end
        constructor += ""
        
        t0 = Time.now
        `#{constructor} > #{parr[0]}.log`
        #p $?.success?
        #p $?
        #puts "#{constructor} > #{parr[0]}.log"
        time = Time.now - t0
        #abort('ere')
        # output progress
        if parr[0]%1000==0
          puts "Currently on #{parr[0]} / #{output_parameters.length}. This run took #{time}"
        end
        # assembly decides the directory group in which output file will be placed
        groupceil = (parr[0] / groupsize).ceil * groupsize
        destdir = "#{(groupceil - (groupsize-1)).to_i}-#{groupceil.to_i}"
        # create the directory group (if not exist)
        Dir.mkdir(destdir) unless File.directory?(destdir)
        # create parr[0]put file for output of current assembly number from soapdt
        Dir.mkdir("#{destdir}/#{parr[0]}") unless File.directory?("#{destdir}/#{parr[0]}")
        # loop through output files from soap and move parr[0]put files to relevent directory
        Dir["#{parr[0]}.*"].each do |file|
          # Dir['#{.parr[0]}.*'] will grab the directory group file (destdir) of the first parr[0]put in each destdir file and attempt to gzip
          if file == destdir then
            next
          end
          `gzip #{parr[0]}.* 2> /dev/null`
          file = file.gsub(/\.gz/, '')
          # move produced files to directory group
          FileUtils.mv("#{file}.gz", "#{destdir}/#{parr[0]}")
          # write parameters to filenameToParameters.csv which includes a reference of filename to parameters
          mutex = Mutex.new
          CSV.open("filenameToParameters.csv", "ab") do |csv|
            mutex.synchronize do
             csv << [parr + time]
            end
          end
        end
      end
    end
  end

  def run_soap()
    cmd = "#{$SOAP_file_path} all"
    cmd += " -s soapdt.config" # config file
    cmd += " -a 0.5" # memory assumption
    cmd += " -o #{parr[0] }" # parr[0] put directory
    cmd += " -K #{kcap}" # kmer sizex`
    cmd += " -p #{$opts[:threads]}" # number of threads
    cmd += " -d #{d}" # minimum kmer frequency
    cmd += " -F" # fill gaps in scaffold
    cmd += " -M #{m}" # strength of contig flattening
    cmd += " -D #{dcap}" # delete edges with coverage no greater than
    cmd += " -L #{lcap}" # minimum contig length
    cmd += " -u" # unmask high coverage contigs before scaffolding
    cmd += " -e #{e}" # delete contigs with coverage no greater than
    cmd += " -t #{t}" # maximum number of transcripts from one locus
 end
  # returns an array of arrays of input parameters
  def give_input_parameters
    return @input_parameters
  end

  # generate all the parameter combinations to be applied to soapdt
  def generate_combinations(index=0, opts={})

    if index == @input_parameters.length

      # save generated parameters
      # @options.map{|key, value| opts[key.to_sym]}
      #  the options that the user wants to vary is saved in @options
      #  opts[key] will contain the value of each option for this current parameter set
      @input_combinations << [@parameter_counter] + @input_parameters.map{|key, value| opts[key.to_sym]}
      @parameter_counter += 1
      return
    end
    key = @input_parameters.keys[index]
    @input_parameters[key].each do |value|
      opts[key] = value
      generate_combinations(index+1, opts)
    end
  end

  def generate_configfile
    # make config file
    rf = @input_parameters[:readformat] == 'fastq' ? 'q' : 'f'
    File.open("soapdt.config", "w") do |conf|
      conf.puts "max_rd_len=20000"
      conf.puts "[LIB]"
      conf.puts "avg_ins=#{@input_parameters[:insertsize][0]}"
      conf.puts "reverse_seq=0"
      conf.puts "asm_flags=3"
      conf.puts "rank=2"
      conf.puts "#{rf}1=#{@input_parameters[:inputDataLeft][0]}"
      conf.puts "#{rf}2=#{@input_parameters[:inputDataRight][0]}"
    end
    @input_parameters.delete(:readformat)
    @input_parameters.delete(:insertsize)
    @input_parameters.delete(:inputDataLeft)
    @input_parameters.delete(:inputDataRight)
    # threads should be removed later
    @input_parameters.delete(:threads)
  end
end

ranges = {
  :readformat => 'fastq',
  :threads => 1,
  :insertsize => 200,
  :inputDataLeft => '../inputdata/l.fq',
  :inputDataRight => '../inputdata/r.fq',
  :K => (3..5).to_a,
  :d => (6..8).to_a, # KmerFreqCutoff: delete kmers with frequency no larger than (default 0)
  :M => (0..2).to_a, # def 1, min 0, max 3 #k value
}

soapdt = ParameterSweeper.new(ranges, "ra")
soapdt.run(200.00)