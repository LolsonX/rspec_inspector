# frozen_string_literal: true

require_relative 'rspec_inspector/version'

# RSpecInspector is a gem that provides more information about state when test failed
# it is useful to track flakey tests
module RSpecInspector
  LET_METHOD_DEFINITION = RSpec::Core::MemoizedHelpers::ClassMethods.instance_method(:let).source_location
  LET_METHOD_DEFINITION_START = LET_METHOD_DEFINITION.last
  # Using source location method we can find first line of definition
  # To find end line the easiest way to do this is to read a File with defintion
  # Then starting with the definition line try to build abstract tree
  def self.find_let_definition_length
    # Buffer to keep read lines
    lines = []
    # get file location and let method starting line
    file, line = LET_METHOD_DEFINITION
    File.read(file).lines[line - 1..].each do |l|
      lines << l
      # Try to build abstract tree
      RubyVM::AbstractSyntaxTree.parse(lines.join)
      # if it gets here it means that syntax tree was valid therefore we have
      # found end of let method definition
      break
    rescue SyntaxError
      # if Syntax Error is raised it means that invalid ruby code was read
      # therefore we are trying to get next line
      next
    end
    # indexing start with 0 in programming so we need to correct the length to also start from 0
    lines.length - 1
  end
  LET_METHOD_DEFINITION_END = LET_METHOD_DEFINITION_START + RSpecInspector.find_let_definition_length

  class << self
    def initialize
      RSpec.configure do |config|
        config.after do |example|
          # Skip if there was no exception
          next unless example.exception

          RSpecInspector.output(example, self, RSpecInspector.find_memoized_vars(self))
        end
      end
    end

    def find_memoized_vars(context)
      # Get methods defined by RSpec 'let' calls
      context.methods.filter_map do |m|
        # Get location of definition of method with name 'm'
        location = context.method(m).source_location
        # If it's nil get next because it means it is built-in method
        next unless location

        # location format is Array[file_path, line_number]

        m if RSpecInspector.memoized_value?(location)
      end
    end

    def memoized_value?(location)
      range = (RSpecInspector::LET_METHOD_DEFINITION_START..RSpecInspector::LET_METHOD_DEFINITION_END)
      # RSpec creates memoized helpers using define_method. Ruby's source location
      # return place of using define_method. That's why it is needed to check
      # if source is in 'memoize_helpers.rb' and to check if it was defined inside 'let' method
      # definition. 'memoize_helpers.rb' defines 'let' method that
      range.include?(location.last) && location.first == RSpecInspector::LET_METHOD_DEFINITION.first
    end

    def output(example, context, values)
      summary = []
      values.uniq.each do |m|
        # Evaluate the helper to get it's value
        evaluated_value = context.send(m)
        summary << "\t#{m}: #{evaluated_value.inspect}"
      end
      RSpecInspector.log_message(RSpecInspector.message(example, summary))
    end

    def message(example, summary)
      <<~MSG
        [RSpec Inspector] Test: #{example.description.titleize} failed.
          Test variables: \n\t#{summary.join("\n\t")}
        [RSpec Inspector] Dump finished")
      MSG
    end

    def log_message(message)
      if defined?(Rails)
        Rails.logger.error(message)
      else
        warn(message)
      end
    end
  end
end
