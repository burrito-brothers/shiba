[![Build Status](https://travis-ci.com/burrito-brothers/shiba.svg?branch=master)](https://travis-ci.com/burrito-brothers/shiba)

# Shiba

Shiba is a tool that helps catch poorly performing queries before they cause problems in production, including:

* Full table scans
* Poorly performing indexes

By default, it will pretty much only detect queries that miss indexes. As it's fed more information, it warns about advanced problems, such as queries that use indexes but are still very expensive. To help find such queries, Shiba monitors test runs for ActiveRecord queries. A warning and report are then generated

## Installation

Install using bundler. Note: this gem is not designed to be run on production.

```ruby
# Gemfile
gem 'shiba', :group => :test
```

If your application lazy loads gems, you will to manually require it.

```ruby
# config/environments/test.rb or test/test_helper.rb
require 'shiba/setup'
```

## Usage

A report will only be generated when problem queries are detected.
To verify shiba is actually running, you can run your tests with SHIBA_DEBUG=true.

```ruby
# Install
bundle

# Run some tests using to generate a SQL report
rake test:functional
rails test test/controllers/users_controller_test.rb
SHIBA_DEBUG=true ruby test/controllers/users_controller_test.rb

# 1 problematic query detected
# Report available at /tmp/shiba-explain.log-1550099512
```

### Screenshot
`open /tmp/shiba-explain.log-1550099512`
![screenshot](/data/screenshot.png?raw=true)


## Typical query problems

Here are some typical query problems Shiba can detect. We'll assume the following schema:

```ruby
create_table :users do |t|
  t.string :name
  t.string :email
  # add an organization_id column with an index
  t.references :organization, index: true

  t.timestamps
end
```

#### Full table scans

The most simple case to detect are queries that don't utilize indexes. While it isn't a problem to scan small tables, often tables will grow large enough where this can become a serious issue.

```ruby
user = User.where(email: 'squirrel@example.com').limit(1)
```

Without an index, the database will read every row in the table until it finds one with an email address that matches. By adding an index, the database can perform a quick lookup for the record.

#### Non selective indexes

Another common case is queries that use an index, and work fine in the average case, but the distribution is non normal. These issues can be hard to track down and often impact large customers.

```ruby
users = User.where(organization_id: 1)
users.size
# => 75

users = User.where(organization_id: 42)
users.size
# => 52,000
```

Normally a query like this would only become a problem as the app grows in popularity. Fixes include adding `limit` or `find_each`.

With more data, Shiba can help detect this issue when it appears in a pull request.

## Going beyond table scans

Without more information, Shiba acts as a simple missed index detector. To catch other problems that can bring down production (or at least cause some performance issues), Shiba requires general statistics about production data, such as the number of rows in a table and how unique columns are.

This information can be obtained by running the bin/dump_stats command in production.

```console
production$
git clone https://github.com/burrito-brothers/shiba.git
cd shiba ; bundle
bin/mysql_dump_stats -d DATABASE_NAME -h HOST -u USER -pPASS  > ~/shiba_index.yml

local$
scp production:~/shiba_index.yml RAILS_PROJECT/config
```

The stats file will look similar to the following:
```console
local$ head <rails_project>/config/shiba_index.yml
```
```yaml
users:
  count: 10000
  indexes:
    PRIMARY:
      name: PRIMARY
      columns:
      - column: id
        rows_per: 1 # one row per unique `id`
      unique: true
    index_users_on_email:
      name: index_users_on_email
      columns:
      - column: email
        rows_per: 1 # one row per email address (also unique)
      unique: true
    index_users_on_organization_id:
      name: index_users_on_organization_id
      columns:
      - column: organization_id
        rows_per: 20% # each organization has, on average, 20% or 2000 users.
      unique: false
```

## Automatic pull request reviews

Shiba can automatically comment on Github pull requests when code changes appear to introduce a query issue. The comments are similar to those in the query report dashboard. This guide will walk through setup on Travis CI, but other CI services should work in a similar fashion.

Once Shiba is installed, the `shiba review` command needs to be run after the tests are finished. On Travis, this goes in an after_script setting:

```yml
# .travis.yml
after_script:
 - bundle exec shiba review --submit
 ```
 
The `--submit` option tells Shiba to comment on the relevant PR when an issue is found. To do this, it will need the Github API token of a user that has access to the repo. Shiba's comments will appear to come from that user, so you'll likely want to setup a bot account on Github with repo access for this.
 
By default, the review script looks for an environment variable named  GITHUB_TOKEN that can be specified at https://travis-ci.com/{organization}/{repo}/settings. The token can be generated on Github at https://github.com/settings/tokens. If you have another environment variable name for your Github token, it can be manually configured using the `--token` flag.
 
```yml
# .travis.yml
after_script:
 - bundle exec shiba review --token $MY_GITHUB_API_TOKEN --submit
 ```
