require 'securerandom'
require 'fileutils'

# Assembly Optimisation Framework: Objective Function Handler
#
# == Description
#
# The Handler manages the objective functions for the optimisation experiment.
# Specifically, it finds all the objective functions and runs them when requested,
# outputting the results to the main Optimiser.
#
# == Explanation
#
# === Loading objective functions
#
# The Handler expects a directory containing objectives (by default it looks in *currentdir/objectives*).
# The *objectives* directory should contain the following:
#
# * a *.rb* file for each objective function. The file should define a subclass of ObjectiveFunction
# * (optionally) a file *objectives.txt* which lists the objective function files to use
#
# If the objectives.txt file is absent, the subset of objectives to use can be set directly in the Optimiser
# , or if no such restriction is set, the whole set of objectives will be run.
#
# Each file listed in *objectives.txt* is loaded if it exists.
#
# === Running objective functions
#
# The Handler iterates through the objectives, calling the *run()* method
# of each by passing the assembly. After collecting results, it returns
# a Hash of the results to the parent Optimiser.
module Biopsy

  class ObjectiveHandlerError < Exception
  end

  class ObjectiveHandler

    attr_reader :last_tempdir
    attr_accessor :objectives

    def initialize domain, target
      @domain = domain
      @target = target
      base_dir = Settings.instance.base_dir
      @objectives_dir = Settings.instance.objectives_dir.first
      @objectives = {}
      $LOAD_PATH.unshift(@objectives_dir)
      @subset = Settings.instance.respond_to?(:objectives_subset) ? Settings.instance.objectives_subset : nil
      self.load_objectives
      # pass objective list back to caller
      return @objectives.keys
    end

    def load_objectives
      # load objectives
      # load subset list if available
      subset_file = @objectives_dir + '/objectives.txt'
      subset = File.exists?(subset_file) ? File.open(subset_file).readlines.map{ |l| l.strip } : nil
      subset = @subset if subset.nil?
      # parse in objectives
      Dir.chdir @objectives_dir do
        Dir['*.rb'].each do |f|
          file_name = File.basename(f, '.rb')
          require file_name
          objective_name = file_name.camelize
          objective =  Module.const_get(objective_name).new
          if subset.nil? or subset.include?(file_name)
            # this objective is included
            @objectives[objective_name] = objective
          end
        end
        # puts "loaded #{@objectives.length} objectives."
      end
    end

    # Run a specific +:objective+ on the +:output+ of a target
    # with max +:threads+.
    def run_objective(objective, name, output, threads)
      begin
        # output is a hash containing the file(s) output
        # by the target in the format expected by the
        # objective function(s).
        return objective.run(output, threads)
      rescue NotImplementedError => e
        puts "Error: objective function #{objective.class} does not implement the run() method"
        puts "Please refer to the documentation for instructions on adding objective functions"
        raise e
      end
    end

    # Perform a euclidean distance dimension reduction of multiple objectives
    # using weighting specified in the domain definition.
    def dimension_reduce(results)
      # calculate the weighted Euclidean distance from optimal
      # d(p, q) = \sqrt{(p_1 - q_1)^2 + (p_2 - q_2)^2+...+(p_i - q_i)^2+...+(p_n - q_n)^2}
      # here the max value is sqrt(n) where n is no. of results, min value (optimum) is 0
      total = 0
      results.each_pair do |key, value|
        o = value[:optimum]
        w = value[:weighting]
        a = value[:result]
        m = value[:max]
        total += w * (((o - a)/m) ** 2)
      end
      return Math.sqrt(total) / results.length
    end

    # Run all objectives functions for +:output+. 
    def run_for_output(output, threads=6, cleanup=true, allresults=false)
      # check output files exist
      @target.output_files.each_pair do |key, name|
        unless File.exists?(output[key]) && File.size(output[key]) > 0
          info("file #{output[key]} does not exist or is empty")
          return nil
        end
      end
      # run all objectives for output
      results = {}
      # create temp dir
      Dir.chdir(self.create_tempdir) do
        @objectives.each_pair do |name, objective|
          results[name] = self.run_objective(objective, name, output, threads)
        end
        if cleanup == 1
          # remove all but essential files
          essential_files = @domain.keep_intermediates
          if essential_files
            @objectives.values.each{ |objective| essential_files += objective.essential_files }
          end
          Dir["*"].each do |file|
            next if File.directory? file
            if essential_files && essential_files.include?(file)
              `gzip #{file}` if @domain.gzip_intermediates
              FileUtils.mv("#{file}.gz", '..')
            end
          end
        end
      end
      if cleanup
        # clean up temp dir
        FileUtils.rm_rf @last_tempdir
      end
      if allresults
        return {:results => results,
                :reduced => self.dimension_reduce(results)}
      else
        results.each do |key, value|
          return value[:result]
        end
      end
    end

    # create a guaranteed random temporary directory for storing outputs
    # return the dirname
    def create_tempdir
      token = loop do
        # generate random dirnames until we find one that
        # doesn't exist
        test_token = SecureRandom.hex
        break test_token unless File.exists? test_token
      end
      Dir.mkdir(token)
      @last_tempdir = token
      return token
    end

  end

end
