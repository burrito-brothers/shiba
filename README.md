# Shiba

Shiba is a tool that helps you to understand and write better SQL.  Integrate
the gem into your test suite, give Shiba a bit of data about your indexes, and Shiba
will let you know the impact of your queries on production, with the goal of catching
poorly performing queries before they hit production.

## Installation

You can run shiba either as a gem in your test suite, or as a standalone utility.

### Standalone:

```

local:$ git clone git@github.com:burrito-brothers/shiba.git

# get index statistics from a production database, or a staging database with
# that resembles production:

local:$ ssh production_host

# dump index statistics from DATABASE
production_host:$ mysql -ABe "select * from information_schema.statistics where table_schema = 'DATABASE'" > shiba_schema_stats.tsv

local:$ scp production_host:shiba_schema_stats.tsv shiba/

# set shiba loose on your queries!


local:$ cd myproject
local:$ cat development.log |


cd shiba
bin/analyze.rb

```


There's two main ways to run Shiba, either as a gem integrated into your
environment, or as a standalone application.

### Gem

```

Add this line to your application's Gemfile:

```ruby
group :test do
  gem 'shiba'
end
```

## Stats collection

In order to get the most out of Shiba,
ssh production

```
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install shiba

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/osheroff/shiba. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the Shiba project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/osheroff/shiba/blob/master/CODE_OF_CONDUCT.md).
