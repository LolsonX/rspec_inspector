# RSpecInspector

RSpecInspector is a tool for inspecting memoized values after test fails.
It might be useful for flaky tests occuring on CI pipeline.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add rspec_inspector

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rspec_inspector

**You may not want to use it in production environment**
## Usage

run
```ruby
RSpecInspector.initialize
```
In Your spec_helper.rb

## Development

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/LolsonX/rspec_inspector.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
