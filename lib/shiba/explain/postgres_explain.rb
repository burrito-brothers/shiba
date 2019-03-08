require 'shiba/parsers/postgres_explain_index_conditions'

module Shiba
  class Explain
    class PostgresExplain
      def initialize(json)
        @json = json
        @state = {}
      end

      def with_state(hash)
        old_state = @state
        @state = @state.merge(hash)
        yield
        @state = old_state
      end

      def transform_node(node, array)
        case node['Node Type']
        when "Limit", "LockRows", "Aggregate", "Unique", "Sort", "Hash", "ProjectSet"
          recurse_plans(node, array)
        when "Nested Loop"
          with_state(join_type: node["Join Type"]) do
            recurse_plans(node, array)
          end
        when "Hash Join"
          join_fields = extract_join_key_parts(node['Hash Cond'])
          with_state(join_fields: join_fields, join_type: "Hash") do
            recurse_plans(node, array)
          end
        when "Bitmap Heap Scan"
          with_state(table: node['Relation Name']) do
            recurse_plans(node, array)
          end
        when "Seq Scan"
          array << {
            "table" => node["Relation Name"],
            "access_type" => "ALL",
            "key" => nil,
            "filter" => node["Filter"]
          }
        when "Index Scan", "Bitmap Index Scan", "Index Only Scan"
          table = node["Relation Name"] || @state[:table]

          if node['Index Cond']
            used_key_parts = extract_used_key_parts(node['Index Cond'])
          else
            used_key_parts = []
          end

          h = {
            "table" => node["Relation Name"] || @state[:table],
            "access_type" => "ref",
            "key" => node["Index Name"],
            "used_key_parts" => used_key_parts
          }

          if node['Node Type'] == "Index Only Scan"
            h['using_index'] = true
          end

          array << h
        else
          raise "unhandled node: #{node}"
        end
        array
      end

      def extract_used_key_parts(cond)
        conds = Parsers::PostgresExplainIndexConditions.new(cond)
        conds.fields
      end

      def extract_join_key_parts(cond)
        conds = Parsers::PostgresExplainIndexConditions.new(cond)
        conds.join_fields
      end

      def recurse_plans(node, array)
        node['Plans'].each do |n|
          transform_node(n, array)
        end
      end

      def transform
        plan = @json.first['Plan']
        transform_node(plan, [])
      end
    end
  end
end
