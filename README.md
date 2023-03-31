# RailsRubyLsp

The RailsRubyLsp is a [Ruby LSP](https://github.com/Shopify/ruby-lsp) extension for extra Rails editor features. As long
as this gem is a part of the project's bundle, the Ruby LSP will automatically load it to provide extra features.

## Usage

This gem includes two elements that together allow for more Rails functionality in the editor. The first is a Rails
engine that automatically exposes some APIs when running the Rails server in development mode. The second is a Ruby LSP
extension that knows how to connect to the exposed APIs to fetch runtime information from the Rails server.

In order to get the extra functionality in the editor, the Rails server must be running.

Note: the Ruby LSP does not need to be restarted every time the Rails server is booted. If you need to shutdown the
server, the extra features will simply disappear and come back once the server is running again.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "rails_ruby_lsp"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/rails_ruby_lsp. This project is
intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the
[Contributor Covenant](https://github.com/Shopify/rails_ruby_lsp/blob/main/CODE_OF_CONDUCT.md) code of conduct.

## License

The gem is available as open source under the terms of the
[MIT License](https://github.com/Shopify/rails_ruby_lsp/blob/main/LICENSE.txt).
