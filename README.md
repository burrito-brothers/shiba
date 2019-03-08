[![Build Status](https://travis-ci.com/burrito-brothers/shiba.svg?branch=master)](https://travis-ci.com/burrito-brothers/shiba)

# Shiba

Shiba is a tool (currently in alpha) that automatically reviews SQL queries before they cause problems in production. It uses production statistics for realistic query analysis. It catches missing indexes, overly broad indexes, and queries that return too much data.

![screenshot](https://shiba-sql.com/wp-content/uploads/2019/03/shiba-screenshot-1024x581.png)

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

To get started, try out shiba locally. To verify shiba is actually running, you can run your tests with SHIBA_DEBUG=true.

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

## Next steps
* [Integrate with Github pull requests](#automatic-pull-request-reviews)
* [Add production stats for realistic analysis](#going-beyond-table-scans)
* [Preview queries from the developer console](#analyze-queries-from-the-developer-console)
* [Read more about typical query problems](#typical-query-problems)



### Going beyond table scans

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

### Automatic pull request reviews

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
 
#### CircleCI Integration
 
To integrate with CircleCI, add this after the the test run step in `.circleci/config.yml`.
 
 ```yml
# .circleci/config.yml
- run:
    name: Review SQL queries
    command: bundle exec shiba review --submit
```

An environment variable named `GITHUB_TOKEN` will need to be configured on CircleCI under *Project settings > Environment Variables*

#### Custom Integration

To run on other servers, two steps are required:
1. Ensure an environment variable named `CI` is set when the tests and shiba script are run.
2. Run the `shiba review` command after tests are run, supplying the required arguments to `--submit, --token, --branch, and --pull-request`. For example:

```bash
CI=true
rake test
bundle exec shiba review --submit --token $MY_GITHUB_TOKEN --branch $(git rev-parse HEAD) --pull-request $MY_PR_NUMBER
```

### Analyze queries from the developer console

For quick analysis, queries can be analyzed from the Rails console.
```ruby
# rails console
[1] pry(main)> require 'shiba/console'
=> true
[2] pry(main)> shiba User.where(email: "squirrel@example.com")

Severity: high
----------------------------
Fuzzed Data: Table sizes estimated as follows -- 100000: users
Table Scan: The database reads 100% (100000) of the of the rows in **users**, skipping any indexes.
Results: The database returns 100000 row(s) to the client.
Estimated query time: 3.02s

=> #<Shiba::Console::ExplainRecord:0x00007ffc154e6128>: 'SELECT `users`.* FROM `users` WHERE `users`.`email` = 'squirrel@example.com''. Call the 'help' method on this object for more info.
[3] pry(main)> 
```

Raw query strings are also supported, e.g. `shiba "select * from users where users.email = 'squirrel@example.com'"`


### Typical query problems

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
