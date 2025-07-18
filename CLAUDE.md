# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ruby LSP Rails is a Ruby Language Server Protocol (LSP) add-on that provides Rails-specific editor features. It's designed to work with the Ruby LSP to enhance Rails development experience in supported editors.

## Development Commands

### Testing
- `bundle exec rake` - Run full test suite (sets up dummy app database and runs all tests)
- `bin/rails test test/my_test.rb` - Run a specific test file
- `bundle exec rake test` - Alternative way to run tests

### Linting and Code Quality
- `bin/rubocop` - Run RuboCop linting
- `bundle exec srb tc` - Run Sorbet type checking

### Development Server (for dummy app)
- `bin/rails server` - Start Rails server for the dummy app in test/dummy

### Database
- Database setup is handled automatically when running the full test suite
- The dummy Rails app is located in `test/dummy/` and is used for testing

## Architecture

### Core Components

**Main Entry Point**: `lib/ruby-lsp-rails.rb` - Simple entry point that requires the version file

**Addon System**: `lib/ruby_lsp/ruby_lsp_rails/addon.rb` - Main addon class that extends RubyLsp::Addon
- Manages lifecycle (activate/deactivate)
- Coordinates feature listeners (hover, completion, definition, etc.)
- Handles Rails-specific functionality like migration prompts
- Uses background thread to initialize Rails runner client

**Server Component**: `lib/ruby_lsp/ruby_lsp_rails/server.rb` - Separate Rails process server
- Runs as isolated process to handle Rails-specific queries
- Provides database schema information, model details, associations
- Handles route information and migration status
- Communicates via JSON-RPC over stdin/stdout

**Feature Modules**:
- `hover.rb` - Provides hover information for Rails concepts
- `definition.rb` - Go-to-definition for Rails constructs  
- `completion.rb` - Rails-specific autocompletion
- `code_lens.rb` - Code lens features
- `document_symbol.rb` - Document symbol provider
- `indexing_enhancement.rb` - Enhanced indexing for Rails

**Support Modules**:
- `support/associations.rb` - ActiveRecord associations handling
- `support/callbacks.rb` - Rails callbacks support
- `support/location_builder.rb` - Location utilities
- `runner_client.rb` - Client for communicating with server process

### Test Structure

**Dummy Rails App**: `test/dummy/` contains a minimal Rails 8.0 application for testing
- Standard Rails structure with models, controllers, views
- Database migrations and schema
- Used to test Rails-specific features in realistic environment

**Test Files**: Located in `test/ruby_lsp_rails/` with corresponding `_test.rb` files for each feature module

### Type System

The project uses Sorbet for static typing:
- `# typed: strict` annotations on most files
- Type signatures using RBI format
- Sorbet configuration in `sorbet/config`
- Generated RBI files in `sorbet/rbi/`

### Development Tools

- **Dev.yml**: Shopify's development configuration for streamlined setup
- **Tapioca**: For RBI generation (`bin/tapioca`)
- **Bundler**: Standard Ruby dependency management
- **Rake**: Build automation and test running