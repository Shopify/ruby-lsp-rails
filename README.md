# Ruby LSP Rails

Ruby LSP Rails is a [Ruby LSP](https://github.com/Shopify/ruby-lsp) addon for extra Rails editor features, such as:

- Displaying an ActiveRecord model's database columns and types when hovering over it
- Running tests and debugging tests through the terminal or the editor's UI

## Installation

If you haven't already done so, you'll need to first [set up Ruby LSP](https://github.com/Shopify/ruby-lsp#usage).

As of v0.3.0, Ruby LSP will automatically include the Ruby LSP Rails addon in its custom bundle when a Rails app is detected.
There is no need to add the gem to your bundle.

## Features

* Hover over an ActiveRecord model to reveal its schema.
* Run or debug a test by clicking on the code lens which appears above the test class, or an individual test.
* Navigate to validations, callbacks and test cases using your editor's "Go to Symbol" feature, or outline view.

## Documentation

See the [documentation](https://shopify.github.io/ruby-lsp-rails) for more in-depth details about the
[supported features](https://shopify.github.io/ruby-lsp-rails/RubyLsp/Rails.html).

## How Runtime Introspection Works

LSP tooling is typically based on static analysis, but `ruby-lsp-rails` actually communicates with your Rails app for
some features.

When Ruby LSP Rails starts, it spawns a `rails runner` instance which runs
[`server.rb`](https://github.com/Shopify/ruby-lsp-rails/blob/main/lib/ruby_lsp/ruby_lsp_rails/server.rb).
The addon communicates with this process over a pipe (i.e. `stdin` and `stdout`) to fetch runtime information about the application.

When extension is stopped (e.g. by quitting the editor), the server instance is shut down.

> [!NOTE]
> Prior to v0.3.0, `ruby-lsp-rails` used a different approach which involved mounting a Rack application within the Rails app.
> That approach was brittle and susceptible to the application's configuration, such as routing and middleware.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/ruby-lsp-rails. This project is
intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the
[Contributor Covenant](https://github.com/Shopify/ruby-lsp-rails/blob/main/CODE_OF_CONDUCT.md) code of conduct.

## License

The gem is available as open source under the terms of the
[MIT License](https://github.com/Shopify/ruby-lsp-rails/blob/main/LICENSE.txt).
