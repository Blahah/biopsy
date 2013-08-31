# Optimisation Framework: Settings
#
# == Description
#
# The Settings singleton object maintains general settings (as opposed to
# those specific to the experiment, which are contained in the Experiment
# object).
#
# Key settings include the location(s) of config file(s), the Domain that
# is currently active, and the directories to search for objective functions.
#
# Methods are provided for loading, listing, accessing and saving the settings
#
module Biopsy

  require 'singleton'
  require 'yaml'
  require 'pp'

  class SettingsError < StandardError
  end

  class Settings
    include Singleton

    attr_reader :_settings

    def initialize
      self.clear
      @config_file = '~/.biopsyrc'
      self.set_defaults
    end

    # Loads settings from a YAML config file. If no file is
    # specified, the default location ('~/.biopsyrc') is used.
    # Settings loaded from the file are merged into any
    # previously loaded settings.
    def load(config_file=@config_file)
      newsets = YAML::load_file(config_file)
      raise 'Config file was not valid YAML' if newsets == false
      @_settings = @_settings.deep_merge newsets.deep_symbolize
    end

    # Set defaults for settings
    def set_defaults
      self.base_dir = ['.']
      self.target_dir = ['targets']
      self.domain_dir = ['domains']
      self.domain = 'test_domain'
      self.objectives_dir = ['objectives']
      self.objectives_subset = []
      self.sweep_cutoff = 100
    end

    # Saves the settings to a YAML config file. If no file is
    # specified, the default location ('~/.biopsyrc') is used.
    def save(config_file=@config_file)
      ::File.open(config_file, 'w') do |f|
        f.puts self.to_s
      end
    end

    # Defines methods dynamically based on the contents of the
    # settings store. E.g. if the settings store has a key
    # :the_key, the method Settings.instance.the_key will be
    # valid.
    # Also allows arbitrary new methods to be defined using normal
    # assignent. E.g. if there is no key :the_key, then
    # Settings.instance.the_key = 'the value' will create it.
    def method_missing(name, *args, &block)
      if args.empty?
        # access the value
        @_settings[name.to_sym] || super
      elsif name.to_s[-1] == '='
        # assign the value
        @_settings[name.to_s[0..-2].to_sym] = args[0]
      end
    end

    # See above
    def respond_to_missing?(name, include_private = false)
      @_settings.has_key? name.to_sym || super
    end

    # Returns a flat array of the settings
    def list_settings
      @_settings.flatten
    end

    # Returns a YAML string representation of the settings
    def to_s
      @_settings.to_yaml
    end

    # empties the settings
    def clear
      @_settings = {}
    end

    # Locate the first YAML config file whose name
    # excluding extension matches +:name+ (case insensitive)
    # in dirs listed by the +:dir_key+ setting.
    def locate_config(dir_key, name)
      unless @_settings.has_key? dir_key
        raise SettingsError.new "no setting found for compulsory key #{dir_key}"
      end
      @_settings[dir_key].each do |dir|
        Dir.chdir ::File.expand_path(dir) do
          Dir[name + '.yml'].each do |file|
            return ::File.expand_path(file) if ::File.basename(file, '.yml').downcase == name.downcase
          end
        end
      end

      nil
    end

  end # Settings

end # Biopsy
