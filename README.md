# Shiba

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'shiba'
```

## Stats collection

ssh production

```
ssh produciton_host
mysql -u <USER> -p<PASSWORD> -ABe 'select * from information_schema.statistics where table_schema = "<DATABASE>";' > schema_stats.tsv
mkdir .shiba
scp production_host:schema_stats.tsv .shiba/
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
