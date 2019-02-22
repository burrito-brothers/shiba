module Shiba
  class Explain
    class MysqlExplain
      def transform_table(table, extra = {})
        t = table
        res = {}
        res['table'] = t['table_name']
        res['access_type'] = t['access_type']
        res['key'] = t['key']
        res['used_key_parts'] = t['used_key_parts'] if t['used_key_parts']
        res['rows'] = t['rows_examined_per_scan']
        res['filtered'] = t['filtered']

        if t['ref'] && t['ref'].any? { |r| r != "const" }
          res['join_ref'] = t['ref']
        end

        if t['possible_keys'] && t['possible_keys'] != [res['key']]
          res['possible_keys'] = t['possible_keys']
        end
        res['using_index'] = t['using_index'] if t['using_index']

        res.merge!(extra)

        res
      end

      def transform_json(json, res = [], extra = {})
        rows = []

        if (ordering = json['ordering_operation'])
          index_walk = (ordering['using_filesort'] == false)
          return transform_json(json['ordering_operation'], res, { "index_walk" => index_walk } )
        elsif json['duplicates_removal']
          return transform_json(json['duplicates_removal'], res, extra)
        elsif json['grouping_operation']
          return transform_json(json['grouping_operation'], res, extra)
        elsif !json['nested_loop'] && !json['table']
          return [{'Extra' => json['message']}]
        elsif json['nested_loop']
          json['nested_loop'].map do |nested|
            transform_json(nested, res, extra)
          end
        elsif json['table']
          res << transform_table(json['table'], extra)
        end
        res
      end
    end
  end
end
