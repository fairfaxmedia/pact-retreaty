require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec


task :console do
  require 'irb'
  require 'irb/completion'
  require 'pact/retreaty'
  require 'pry'

  defaults_path = File.expand_path('../defaults.yml', __FILE__)
  defaults = File.exists?(defaults_path) ? YAML.load_file(defaults_path) : {}

  Pact::Retreaty.define_singleton_method(:default_consumer) {
    Pact::Retreaty::Consumer.create do |consumer|
      defaults.each { |k, v| consumer.send("#{k}=", v) }
    end #.best_pact_uri
  }

  ARGV.clear
  IRB.start
end
