# Pact::Retreaty

[Pact](http://github.com/pact/pact) allows the recording of contracts between services and their consumers, but is agnostic about how those contracts are managed. [Retreaty](http://github.com/fairfacemedia/pact-retreaty) extends on that, to provides a ultra light mechanism for pushing these contracts to S3 from a consumer, and later pulling them down to a provider for verification.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pact-retreaty'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pact-retreaty

## Usage

### Consumer-side

Once you've got Pact installed and working, copy this rake task into your Rakefile:

```ruby
namespace :pact do
  desc "Upload pact contracts to S3"
  task :upload do
    require_relative 'spec/service_providers/pact_helper'
    require 'pact/retreaty'

    Pact::Retreaty::Consumer.create do |consumer|
      consumer.name = 'ds-spockly'
      consumer.version = Spockly::VERSION
      consumer.source_glob = "#{Pact.configuration.pact_dir}/*.json"
      consumer.vcs_id = -> { ENV['CI'] ? ENV['CI_BRANCH'] : current_vcs_id }
      consumer.s3_bucket = ENV['PACT_S3_BUCKET']
      consumer.s3_region = ENV['PACT_S3_REGION']
      consumer.access_key_id = ENV['PACT_S3_KEY_ID']
      consumer.access_secret = ENV['PACT_S3_SECRET']
    end.upload_pacts
  end
end
```

Replace the configuration with what makes sense in your consumer - the name and version associated with the current consumer, and an optional lambda to identify the applicable branch from you VCS (Retreaty defaults to Git, and to the branch of the repo it's being run in.)

(It's assumed that this task will usually be running on your CI server, and that you'll set the S3 credentials via environment variables - but you can tweak that behaviour here if you need to.)

When run, the task will load your Pact configuration from your pact_helper file and try to upload all the json files it finds in spec/pacts to the bucket defined. The path inside the bucket will look something like (based on the configuration above, assuming that Spockly::VERSION is '1.0.0' the current branch is 'pact-testing' and the pact is between "Spockly Gem" and "Spock Service"):

```
/ds-spockly/1.0.0/pact-testing/spockly_gem-spock_service.json
```

### Provider-side

The configuration on the provider side looks very similar to the consumer side. Once you've got Pact running with a local contract file, change your pact_helper file to look something like this:

```ruby
require 'pact/retreaty'

Pact.service_provider "Spock Service" do
  honours_pact_with 'Spockly Gem' do
    if ENV['CI'] # CI server
      pact_uri = Pact::Retreaty::Consumer.create do |consumer|
        consumer.name = 'ds-spockly'
        consumer.version = '1.0.0'
        consumer.pactfile = 'spockly_gem-spock_service.json'
        consumer.vcs_fallbacks = -> { [ENV['CI_BRANCH'], :vcs_id, 'develop'] }
        consumer.s3_bucket = ENV['PACT_S3_BUCKET']
        consumer.s3_region = ENV['PACT_S3_REGION']
        consumer.access_key_id = ENV['PACT_S3_KEY_ID']
        consumer.access_secret = ENV['PACT_S3_SECRET']
      end.best_pact_uri
    else # local
      pact_uri '../ds-spockly/spec/pacts/spockly_gem-spock_service.json'
    end
  end
end
```

(In the example above, we're setting the pact_uri based on whether we're running on a CI server - if we're not, we fall back to a local directory as usual.)

The name, version and S3 configurations are identical to the consumer side - the only provider-specific configuration is that we help Retreaty find the right contract by specifying the filename, and we provide a series of options to find the right branch. This deserves some explanation...

###VCS Fallbacks

Over the lifetime of our Pact testing, we'll want to verify various versions of the consumer against a variety of versions of the provider. We have a few mechanisms in place to facilitate this; on the consumer side we track both the 'version' and the 'VCS id' (version control id - usually a branch name) of the current build, and on the provider side we keep a list of options (in order of decreasing specificity) for which of the consumer's VCS ids we'd like to test against. Tracking the branch of the consumer protects us while we're modifying it, so that new versions of the contract don't overwrite the existing stable one - it also frees us from having to change the version for small bug fixes, or during the code review process.

On the consumer side, we can branch in lockstep with the consumer, and then have pact verification before we submit our changes for review - but we can pick a default vcs id ('develop', in the above example) and always fall back to that version of the consumer as a verification target. (Retreaty will try each option in the fallbacks list until it's able to identify and stored contract in S3.)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fairfaxmedia/pact-retreaty.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
