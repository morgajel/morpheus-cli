require 'fileutils'
require 'time'
require 'morpheus/cli/cli_registry'
require 'morpheus/logging'
require 'term/ansicolor'

class Morpheus::Cli::ConfigFile
  include Term::ANSIColor
  class << self
    def init(filename=nil)
      @instance ||= Morpheus::Cli::ConfigFile.new(filename)
    end

    def instance
      #@instance ||= init(Morpheus::Cli.config_filename)
      @instance or raise "#{self}.init() must be called!"
    end

  end

  attr_reader :filename
  attr_reader :config

  def initialize(fn)
    @config = {}
    # only create the file if we're using the default, otherwise error
    if fn
      @filename = File.expand_path(fn)
    else
      @filename = File.expand_path(Morpheus::Cli.config_filename)
      if !Dir.exists?(File.dirname(@filename))
        FileUtils.mkdir_p(File.dirname(@filename))
      end
      if !File.exists?(@filename)
        print "#{Term::ANSIColor.dark}Initializing default config file#{Term::ANSIColor.reset}\n" if Morpheus::Logging.debug?
        FileUtils.touch(@filename)
        save_file()
      end
    end
    load_file()
  end

  def load_file
    #puts "loading config #{@filename}"
    @config = {}
    if !@filename
      return false
    end
    if !File.exist?(@filename)
      raise "Morpheus cli config file not found: #{@filename}"
    end
    file_contents = File.read(@filename)
    file_contents.split
    config_text = File.open(@filename).read
    config_lines = config_text.split(/\n/)
    #config_lines = config_lines.reject {|line| line =~ /^\#/} # strip comments
    config_lines.each_with_index do |line, line_num|
      line = line.strip
      #puts "parsing config line #{line_num} : #{line}"
      next if line.empty?
      next if line =~ /^\#/ # skip comments

      if line =~ /^alias\s+/
        alias_name, command_string = Morpheus::Cli::CliRegistry.parse_alias_definition(line)
        if alias_name.empty? || command_string.empty?
          puts "bad config line #{line_num}: #{line} | Invalid alias declaration"
        else
          # @config[:aliases] ||= []
          # @config[:aliases] << {name: alias_name, command: command_string}
          Morpheus::Cli::CliRegistry.instance.add_alias(alias_name, command_string)
          #puts "registered alias #{alias_name}='#{command_string}'"
        end
      elsif line =~ /^disable-coloring/
        Term::ANSIColor::coloring = false
        # what else do we want to configure in here?
      else
        puts "config line #{line_num} unrecognized : #{line}"
      end
    end

    # if @config[:aliases]
    #   @config[:aliases].each do |it|
    #     Morpheus::Cli::CliRegistry.instance.add_alias(it[:name], it[:command])
    #   end
    # end

    #puts "done loading config from #{}"

    return @config
  end

  def save_file
    if !@filename
      print "#{Term::ANSIColor.dark}Skipping config file save because filename has not been set#{Term::ANSIColor.reset}\n" if Morpheus::Logging.debug?
      return false
    end
    print "#{dark} #=> Saving config file #{@filename}#{reset}\n" if Morpheus::Logging.debug?
    out = ""
    out << "# .morpheusrc file #{@filename}"
    out << "\n"
    out << "# Auto-generated by morpheus #{Morpheus::Cli::VERSION} on #{Time.now.iso8601}"
    out << "\n\n"
    out << "# aliases"
    out << "\n"
    Morpheus::Cli::CliRegistry.instance.all_aliases.each do |k, v|
      out << "alias #{k}='#{v}'"
      out << "\n"
    end
    out << "\n"
    File.open(@filename, 'w') {|f| f.write(out) }
    return true
  end

  # this will load any local changes, and then resave everything in the config (shell)
  def reload_file
    load_file
    save_file
  end

end