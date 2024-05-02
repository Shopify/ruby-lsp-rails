# CONTRIBUTING

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/ruby-lsp-rails. This project is
intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the
[Contributor Covenant](https://github.com/Shopify/ruby-lsp-rails/blob/main/CODE_OF_CONDUCT.md) code of conduct.

# Developing on Ruby LSP

For general information about developing, refer to the to the [documentation](https://github.com/Shopify/ruby-lsp/blob/main/CONTRIBUTING.md#debugging-with-vs-code) for Ruby LSP itself.

### Manually testing a change

The repo includes a dummy Rails app in `test/dummy`. If you're developing a feature, you can add new code to it for testing.

To test with a real Rails application, you can add a Gemfile entry for `ruby-lsp-rails` and point it to your branch.

### Running the test suite

The test suite can be executed by running

```shell
bin/rails test
```
