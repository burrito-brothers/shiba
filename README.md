[![Build Status](https://travis-ci.com/burrito-brothers/shiba.svg?branch=master)](https://travis-ci.com/burrito-brothers/shiba)

# Shiba

Shiba is a tool that helps catch poorly performing queries before they cause problems in production, including:

* Full table scans
* Non selective indexes

By default, it will pretty much only detect queries that miss indexes. As it's fed more information, it warns about advanced problems, such as queries that use indexes but are still very expensive.

To help find such queries, Shiba monitors test runs for ActiveRecord queries. A warning and report are then generated. Shiba is further capable of only warning on changes that occured on a particular git branch/pull request to allow for CI integration.

## Installation

Install using bundler. Note: this gem is not designed to be run on production.

```ruby
gem 'shiba', :group => :test, :require => true
```

## Usage

```ruby
# Install
bundle

# Run some tests using to generate a SQL report
rake test:functional
rails test test/controllers/users_controller_test.rb

# 1 problematic query detected
# Report available at /tmp/shiba-explain.log-1550099512
```

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

For smarter analysis, Shiba requires general statistics about production data, such as the number of rows in a table and how unique columns are.

This information can be obtained by running the bin/dump_stats command in production.

```console
production$ 
git clone https://github.com/burrito-brothers/shiba.git
cd shiba ; bundle
bin/dump_stats DATABASE_NAME [MYSQLOPTS] > ~/shiba_index.yml

local$
scp production:~/shiba_index.yml RAILS_PROJECT/config
```

The stats file will look similar to the following:

```yaml
users:
  count: 10000
  indexes:
    PRIMARY:
      name: PRIMARY
      columns:
      - column: id
        rows_per: 1
      unique: true
    index_users_on_login:
      name: index_users_on_login
      columns:
      - column: login
        rows_per: 1
      unique: true
    index_users_on_created_by_id:
      name: index_users_on_created_by_id
      columns:
      - column: created_by_id
        rows_per: 3
      unique: false
```
