# frozen_string_literal: true

require_relative 'rspec_inspector/version'

# RspecInspector is a gem that provides more information about state when test failed
# it is useful to track flakey tests
module RspecInspector
  LET_METHOD_DEFINITION = RSpec::Core::MemoizedHelpers::ClassMethods.instance_method(:let).source_location.first
  class << self
    def initialize
      RSpec.configure do |config|
        config.after do |example|
          # Skip if there was no exception
          next unless example.exception

          RspecInspector.output(example, self, RspecInspector.find_memoized_vars(self))
        end
      end
    end

    def find_memoized_vars(context)
      puts context.class.ancestors
      # Get methods defined by RSpec 'let' calls
      context.methods.filter_map do |m|
        # Get location of definition of method with name 'm'
        location = context.method(m).source_location
        # If it's nil get next because it means it is built-in method
        next unless location

        # location format is Array[file_path, line_number]

        m if RspecInspector.memoized_value?(location, context.class.name)
      end
    end

    def memoized_value?(location, class_name)
      # Get lines of 'let' method definition. Using Pry because extraction of end of
      # method definition is not trivial and this gem has ability to do that
      range = Pry::Method.from_str("#{class_name}.let").source_range
      # RSpec creates memoized helpers using define_method. Ruby's source location
      # return place of using define_method. That's why it is needed to check
      # if source is in 'memoize_helpers.rb' and to check if it was defined inside 'let' method
      # definition. 'memoize_helpers.rb' defines 'let' method that
      range.include?(location.last) && location.first == RspecInspector::LET_METHOD_DEFINITION
    end

    def output(example, context, values)
      summary = []
      values.uniq.each do |m|
        # Evaluate the helper to get it's value
        evaluated_value = context.send(m)
        summary << "\t#{m}: #{evaluated_value.inspect}"
      end
      RspecInspector.log_message(RspecInspector.message(example, summary))
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
