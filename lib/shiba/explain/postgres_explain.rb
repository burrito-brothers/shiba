require 'shiba/explain/postgres_explain_index_conditions'

module Shiba
  class Explain
    class PostgresExplain
      def initialize(json)
        @json = json
      end


      def transform_node(node, array, current_table=nil)
        case node['Node Type']
        when "Limit", "LockRows", "Aggregate", "Unique", "Sort"
          recurse_plans(node, array, current_table)
        when "Bitmap Heap Scan"
          recurse_plans(node, array, node['Relation Name'])
        when "Seq Scan"
          array << {
            "table" => node["Relation Name"],
            "access_type" => "ALL",
            "key" => nil,
            "filter" => node["Filter"]
          }
        when "Index Scan", "Bitmap Index Scan", "Index Only Scan"
          h = {
            "table" => node["Relation Name"] || current_table,
            "access_type" => "ref",
            "key" => node["Index Name"],
            "used_key_parts" => extract_used_key_parts(node)
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

      def extract_used_key_parts(node)
        conds = PostgresExplainIndexConditions.new(node['Index Cond'])
        conds.fields
      end

      def recurse_plans(node, array, current_table)
        node['Plans'].each do |n|
          transform_node(n, array, current_table)
        end
      end

      def transform
        plan = @json.first['Plan']
        transform_node(plan, [])
      end
    end
  end
end
