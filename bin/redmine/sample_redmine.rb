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
  def enhance(hash, owner)
  end
end

class Attachment < Redmine
  def enhance(hash, owner)
    hash['disk_filename'] = self.attributes['content_url']
  end
end

class Comment < Redmine; end

class Changeset < Redmine
  @@changeset_id = 1

  def enhance(hash, owner)
    hash['id'] = @@changeset_id
    @@changeset_id += 1
    hash['repository_id'] = 1
    hash['scmid'] = 1
  end
end

class Issue < Redmine; end

class Journal < Redmine
  def enhance(hash, owner)
    hash['journalized_type'] = 'Issue'
    hash['journalized_id'] = owner.id
  end
end

class Watcher < Redmine; end
class Relation < Redmine; end
class User < Redmine
  def enhance(hash, owner)
    if rand < 0.01
      hash['type'] = 'admin'
    else
      hash['type'] = 'user'
    end
  end
end

class Sampler
  def initialize(interested_in)
    @results = {}
    @interested_in = interested_in
  end

  def extract_hash(instance, owner = nil)
    h = {}
    table_name = instance.class.name.tableize
    attrs = @interested_in[table_name]

    instance.attributes.each do |k, v|
      if k == "id" || attrs.include?(k)
        h[k] = v
      elsif attrs.include?("#{k}_id")
        h[k + "_id"] = v.id
      elsif v.is_a?(Array) && @interested_in[k]
        v.each do |obj|
          extract_hash(obj, instance)
        end
      end
    end

    instance.enhance(h, owner)

    @results[table_name] ||= []
    @results[table_name] << h
  end

  def get_instance(model, id, params = {})
    model.find(id, params: params) rescue nil
  end

  def find_max(model, start, offset, params)
    last_instance = nil
    while instance = get_instance(model, start + offset, params)
      last_instance = instance
      extract_hash(instance)
      offset *= 2
      sleep(0.5)
    end

    1.upto(6) do |i|
      # check for gaps
      instance = get_instance(model, start + offset + (i**2), params)
      if instance
        last_instance = instance
        extract_hash(instance)
        return find_max(model, start + offset + (i**2), offset, params) || last_instance
      end
    end

    last_instance
  end

  def sample_model(model, params = {})
    # go exponentially up from 1.
    last = find_max(model, 0, 1, params)

    # go up from the last hit value.
    last = find_max(model, last.id, 1, params)

    max_id = last.id
    num_to_sample = (max_id * 0.05).to_i

    num_to_sample.times do
      instance = get_instance(model, rand(max_id), params)
      extract_hash(instance) if instance
      sleep(1)
    end
  end

  def output
    @results.each do |table, res|
      File.open("/tmp/redmine/#{table}.json", "w+") do |f|
        res.each do |row|
          f.puts(row.to_json)
        end
      end
    end
  end
end

client = Mysql2::Client.new(username: 'root', password: '123456', database: 'redmine_test', host: '127.0.0.1')


tables = {
  'attachments' => {
    model: Attachment
  },
  'issues' => {
    model: Issue,
    params: { include: ['journals', 'comments', 'changesets', 'watchers'] },
  },
  'users' => {
    model: User
  }
}


all_tables = tables.map do |k, v|
  a = [k]
  a += v[:params][:include] if v[:params] && v[:params][:include]
  a
end.flatten

table_indexes = {}
all_tables.each do |table|
  indexes = client.query("show indexes from #{table}")
  interested_columns = indexes.to_a.map { |i| i["Column_name"] }.flatten.uniq
  table_indexes[table] = interested_columns
end

sampler = Sampler.new(table_indexes)

tables.each do |table, hash|
  sampler.sample_model(hash[:model], hash[:params])
end

sampler.output

#sample_model(Issue, %w(project_id status_id category_id priority_id author_id))


