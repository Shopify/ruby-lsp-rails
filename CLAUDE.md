# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ruby LSP Rails is a Ruby LSP add-on that provides Rails-specific editor features. It's designed to work with the Ruby LSP to enhance Rails development experience in supported editors.

## Development Commands

### Testing
- `bundle exec rake test` - Run full test suite
- `bin/rails test test/my_test.rb` - Run a specific test file

### Linting and Code Quality
- `bin/rubocop` - Run RuboCop linting
- `bundle exec srb tc` - Run Sorbet type checking

### Database
- Database setup is handled by `bundle exec rails db:setup`
- The dummy Rails app is located in `test/dummy/` and is used for testing

## Architecture

### Core Components

**Main Entry Point**: `lib/ruby_lsp/ruby_lsp_rails/addon.rb`

**Add-on System**: `lib/ruby_lsp/ruby_lsp_rails/addon.rb` - Main add-on class that extends RubyLsp::Addon
- Manages lifecycle (activate/deactivate)
- Coordinates feature listeners (hover, completion, definition, etc.)
- Handles Rails-specific functionality like migration prompts
- Uses background thread to initialize Rails runner client

**Server Component**: `lib/ruby_lsp/ruby_lsp_rails/server.rb` - Separate Rails process server
- Runs as isolated process to handle Rails-specific queries
- Provides database schema information, model details, associations
- Handles route information and migration status
- Communicates via JSON-RPC over stdin/stdout

**Client Component**: `lib/ruby_lsp/ruby_lsp_rails/runner_client.rb`
- Client for communicating with server process

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

### Test Structure

**Dummy Rails App**: `test/dummy/` contains a minimal Rails application for testing
- Standard Rails structure with models, controllers, views
- Database migrations and schema
- Used to test Rails-specific features in realistic environment

**Test Files**: Located in `test/ruby_lsp_rails/`

### Type System

The project uses Sorbet for static typing:
- `# typed: strict` annotations on most files
- Type signatures using Sorbet RBS comments (https://sorbet.org/docs/rbs-support)
- Sorbet configuration in `sorbet/config`
- Generated RBI files in `sorbet/rbi/`
