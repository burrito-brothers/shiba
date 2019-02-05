# Shiba

Shiba is a tool that helps you to understand and write better SQL.  Integrate
the gem into your test suite, give Shiba a bit of data about your indexes, and Shiba
will let you know the impact of your queries on production, with the goal of catching
poorly performing queries before they hit production.

## Installation

You can run shiba either as a gem in your test suite, or as a standalone utility.

### Gem

Add this line to your application's Gemfile:

```ruby
group :test do
  gem 'shiba'
end
```

Run shiba

```ruby
bundle

# Run some some code using shiba to generate a SQL report
bundle exec shiba analyze rake test:functional

# Or run a single test
bundle exec shiba analyze rails test test/controllers/users_controller_test.rb
```

### Standalone:

```
# 1.  Get shiba.
local:$ git clone git@github.com:burrito-brothers/shiba.git

# 2.  Get production data.
# Shiba *can* work without any further data, but it's really best if you can
# dump index statistics from a production database, or a staging database with
# that resembles production.

local:$ ssh production_host
production_host:$ mysql -ABe "select * from information_schema.statistics where table_schema = 'DATABASE'" > shiba_schema_stats.tsv
local:$ scp production_host:shiba_schema_stats.tsv shiba/

# 3.  Analyze your queries.
# set shiba loose on your queries!
# If you can't do step #2, just leave off the '-s' option

local:$ cd shiba
local:$ bin/analyze.rb -h 127.0.0.1 -d TESTDB -u MYSQLUSER -p MYSQLPASS -s shiba_schema_stats.tsv -f ~/src/MYPROJECT/log/test.log > results.json

# analyze the results with `jq`, whynot

local:$ jq -C -s 'sort_by(.cost) | reverse' results.json | less -R

```
