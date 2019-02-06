# Shiba

Shiba is a tool that helps you to understand and write better SQL.  Integrate
the gem into your test suite, give Shiba a bit of data about your indexes, and Shiba
will let you know the impact of your queries on production, with the goal of catching
poorly performing queries before they hit production.

## Installation

You can run shiba either as a gem in your test suite, or as a standalone utility.

### Gem

Install

```ruby
bundle add shiba --group "development, test"
```

Run shiba

```ruby
# Run some tests using shiba to generate a SQL report
rake test:functional
rails test test/controllers/users_controller_test.rb

# When not running tests, ENV['SHIBA_OUT'] is checked.
SHIBA_OUT=query.log rails server
```
