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
        when "Limit", "LockRows", "Aggregate", "Unique", "Sort", "Hash", "ProjectSet", "Materialize"
          recurse_plans(node, array)
        when "Hash Join", "Merge Join", "Nested Loop", "BitmapOr"
          with_state(join_type: node['Node Type']) do
            recurse_plans(node, array)
          end
        when "Bitmap Heap Scan"
          with_state(table: node['Relation Name']) do
            recurse_plans(node, array)
          end
        when "Subquery Scan"
          with_state(subquery: true) do
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

          if @state[:join_type] == 'BitmapOr'
            access_type = "intersect"
          else
            access_type = "ref"
          end

          h = {
            "table" => node["Relation Name"] || @state[:table],
            "access_type" => access_type,
            "key" => node["Index Name"],
            "used_key_parts" => used_key_parts
          }

          if node['Node Type'] == "Index Only Scan"
            h['using_index'] = true
          end

          array << h
        when "Result"
          # TBD: What the hell is here?  seems like queries that short-circuit end up here?
          array << {
            "extra" => "No tables used"
          }
        else
          debugger
          raise "unhandled node: #{node}"
        end
        array
      end

      def extract_used_key_parts(cond)
        begin
          conds = Parsers::PostgresExplainIndexConditions.new(cond)
          conds.fields
        rescue Parsers::BadParse => e
          debugger
          {}
        end
      end

      def extract_join_key_parts(cond)
        begin
          conds = Parsers::PostgresExplainIndexConditions.new(cond)
          conds.join_fields
        rescue Parsers::BadParse => e
          debugger
          {}
        end
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
