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

# set shiba loose on your queries!  the input is `test.log`, which shiba will scan through for queries

local:$ cd shiba
local:$ bin/analyze.rb -h 127.0.0.1 -d TESTDB -u MYSQLUSER -p MYSQLPASS -s shiba_schema_stats.tsv -f ~/src/MYPROJECT/log/test.log > results.json

# analyze the results with `jq`, whynot

local:$ jq -C -s 'sort_by(.cost) | reverse' results.json | less -R

```

### Gem

Add this line to your application's Gemfile:

```ruby
group :test do
  gem 'shiba'
end
```
