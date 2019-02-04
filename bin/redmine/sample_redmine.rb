require 'bundler/setup'

require 'activeresource'
require 'logger'
require 'pp'
require 'mysql2'

ActiveResource::Base.logger = Logger.new($stdout)

class Redmine < ActiveResource::Base
  self.site = 'http://www.redmine.org/'
  self.user = 'osheroff'
  self.password = `cat ~/.redmine_pass`.chomp
end

def extract_hash(instance, attrs, tables)
  h = {}
  instance.attributes.each do |k, v|
    if k == "id" || attrs.include?(k)
      h[k] = v
    elsif attrs.include?("#{k}_id")
      h[k + "_id"] = v.id
    elsif v.is_a?(Array)

    end
  end
  tables[instance.table_name] ||= []
  tables[instance.table_name] << instance
end

def get_instance(model, id)
  model.find(id) rescue nil
end

def find_max(model, attrs, start, offset, tables, params)
  while instance = get_instance(model, start + offset)
    objs << extract_hash(instance, attrs, tables)
    offset *= 2
    sleep(0.5)
  end

  1.upto(6) do |i|
    # check for gaps
    instance = get_instance(model, start + offset + (i**2))
    if instance
      objs << extract_hash(instance, attrs, tables)
      return objs + find_max(model, attrs, start + offset + (i**2), offset, params)
    end
  end

  objs
end

def sample_model(model, attrs, params = {})
  tables = {}
  # go exponentially up from 1.
  objs = find_max(model, attrs, 0, 1, tables, params)
  # go up from the last hit value.
  objs += find_max(model, attrs, objs.last['id'], 1, tables, params)
  pp tables
end

client = Mysql2::Client.new(username: 'root', password: '123456', database: 'redmine_test', host: '127.0.0.1')

class Attachment < Redmine; end
class Comment < Redmine; end
class Changeset < Redmine; end
class Issue < Redmine; end
class Journal < Redmine; end
class Watcher < Redmine; end
class Relation < Redmine; end

tables = {
  'attachments' => {
    model: Attachment
  },
  'issues' => {
    model: Issue,
    params: { include: ['journals', 'commments', 'changesets', 'watchers', 'relations'] },
    sideloaded: [ Journal, Comment, Changeset, Watcher, Relation ]
  }
}
tables.each do |table, hash|
  indexes = client.query("show indexes from #{table}")
  interested_columns = indexes.to_a.map { |i| i["Column_name"] }.flatten.uniq

  sample_model(hash[:model], interested_columns, hash[:params])
end


#sample_model(Issue, %w(project_id status_id category_id priority_id author_id))


