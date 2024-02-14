# Ruby LSP Rails

Ruby LSP Rails is a [Ruby LSP](https://github.com/Shopify/ruby-lsp) addon for extra Rails editor features, such as:

- Displaying an ActiveRecord model's database columns and types when hovering over it
- Running tests and debugging tests through the terminal or the editor's UI

## Installation

To install, add the following line to your application's Gemfile:

```ruby
# Gemfile
group :development do
  gem "ruby-lsp-rails"
end
```
Some features rely on server introspection, and use a Rack server which is automatically mounted by using a Railtie.

For applications with specialized routing requirements, such as custom sharding, this may not be compatible. It can
be disabled with:

```ruby
# config/environments/development.rb
Rails.application.configure do
  # ...
  config.ruby_lsp_rails.server = false
  # ...
end
```

## Usage

### Hover to reveal ActiveRecord schema

1. Start your Rails server
1. Hover over an ActiveRecord model to see its details

### Documentation

See the [documentation](https://shopify.github.io/ruby-lsp-rails) for more in-depth details about the
[supported features](https://shopify.github.io/ruby-lsp-rails/RubyLsp/Rails.html).

### Running Tests

1. Open a test which inherits from `ActiveSupport::TestCase` or one of its descendants, such as `ActionDispatch::IntegrationTest`.
2. Click on the "Run", "Run in Terminal" or "Debug" code lens which appears above the test class, or an individual test.

> [!NOTE]
> When using the Test Explorer view, if your code contains a statement to pause execution (e.g. `debugger`) it will
> cause the test runner to hang.

## How It Works

When Ruby LSP Rails starts, it spawns a `rails runner` instance which runs
`[server.rb](https://github.com/Shopify/ruby-lsp-rails/blob/main/lib/ruby_lsp/ruby_lsp_rails/server.rb)`.
The addon communicates with this process over a pipe (i.e. `stdin` and `stdout`) to fetch runtime information about the application.

When extension is stopped (e.g. by quitting the editor), the server instance is shut down.

> [!NOTE]
> Prior to v0.3, `ruby-lsp-rails` used a different approach which involved mounting a Rack application within the Rails app.
> That approach was brittle and susceptible to the application's configuration, such as routing and middleware.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/ruby-lsp-rails. This project is
intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the
[Contributor Covenant](https://github.com/Shopify/ruby-lsp-rails/blob/main/CODE_OF_CONDUCT.md) code of conduct.

## License

The gem is available as open source under the terms of the
[MIT License](https://github.com/Shopify/ruby-lsp-rails/blob/main/LICENSE.txt).
