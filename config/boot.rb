ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
# See https://stackoverflow.com/questions/79360526/uninitialized-constant-activesupportloggerthreadsafelevellogger-nameerror
require "logger" # Fix concurrent-ruby removing logger dependency which Rails itself does not have
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
