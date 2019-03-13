require 'shiba/explain/check_support'

module Shiba
  class Explain
    class Checks
      include CheckSupport
      extend CheckSupport::ClassMethods

      def initialize(rows, index, stats, options, query, result)
        @rows = rows
        @row = rows[index]
        @index = index
        @stats = stats
        @options = options
        @query = query
        @result = result
        @tbl_message = {}
      end

      attr_reader :cost

      def table
        @row['table']
      end

      def table_size
        @stats.table_count(table)
      end

      def add_message(tag, extra = {})
        @result.messages << { tag: tag, table_size: table_size, table: table }.merge(extra)
      end

      # TODO: need to parse SQL here I think
      def simple_table_scan?
        @rows.size == 1 &&
          (@row['using_index'] || !(@query.sql =~ /\s+WHERE\s+/i)) &&
          (@row['access_type'] == "index" || (@query.sql !~ /order by/i)) &&
          @query.limit
      end

      # TODO: we don't catch some cases like SELECT * from foo where index_col = 1 limit 1
      # bcs we really just need to parse the SQL.
      check :check_simple_table_scan
      def check_simple_table_scan
        if simple_table_scan?
          rows_read = [@query.limit, table_size].min
          @cost = @result.cost = rows_read * Shiba::Explain::COST_PER_ROW_READ
          @result.messages << { tag: 'limited_scan', cost: @result.cost, table: table, rows_read: rows_read }
        end
      end


      check :check_derived
      def check_derived
        if table =~ /<derived.*?>/
          # select count(*) from ( select 1 from foo where blah )
          add_message('derived_table', size: nil)
          @cost = 0
        end
      end

      check :tag_query_type
      def tag_query_type
        @access_type = @row['access_type']

        if @access_type.nil?
          @cost = 0
          return
        end

        @access_type = 'tablescan' if @access_type == 'ALL'
        @access_type = "access_type_" + @access_type
      end

      check :check_join
      def check_join
        if @row['join_ref']
          @access_type.sub!("access_type", "join_type")
          # TODO MAYBE: are multiple-table joins possible?  or does it just ref one table?
          ref = @row['join_ref'].find { |r| r != 'const' }
          table = ref.split('.')[1]
          @tbl_message['join_to'] = table
        end
      end

      #check :check_index_walk
      # disabling this one for now, it's not quite good enough and has a high
      # false-negative rate.
      def check_index_walk
        if first['index_walk']
          @cost = limit
          add_message("index_walk")
        end
      end

      check :check_key_size
      def check_key_size
        if @access_type == "access_type_index"
          # access-type index means a table-scan as performed on an index... all rows.
          key_size = table_size
        elsif @row['key']
          key_size = @stats.estimate_key(table, @row['key'], @row['used_key_parts'])
        else
          key_size = table_size
        end

        # TBD: this appears to come from a couple of bugs.
        # one is we're not handling mysql index-merges, the other is that
        # we're not handling mysql table aliasing.
        if key_size.nil?
          key_size = 1
        end

        if @row['join_ref']
          # when joining, we'll say we read "key_size * (previous result size)" rows -- but up to
          # a max of the table size.  I'm not sure this assumption is *exactly*
          # true but it feels good enough to start; a decent hash join should
          # nullify the cost of re-reading rows.  I think.
          rows_read = [@result.result_size * key_size, table_size || 2**32].min

          # poke holes in this.  Is this even remotely accurate?
          # We're saying that if we join to a a table with 100 rows per item
          # in the index, for each row we'll be joining in 100 more rows.  Is that true?
          @result.result_size *= key_size
        else
          rows_read = key_size
          @result.result_size += key_size
        end

        @cost = Shiba::Explain::COST_PER_ROW_READ * rows_read

        # pin fully missed indexes to a 'low' threshold
        if @access_type == 'access_type_tablescan'
          @cost = [0.01, @cost].max
        end

        @result.cost += @cost

        @tbl_message['cost'] = @cost
        @tbl_message['rows_read'] = rows_read
        @tbl_message['index'] = @row['key']
        @tbl_message['index_used'] = @row['used_key_parts']
        add_message(@access_type, @tbl_message)
      end

      def run_checks!
        _run_checks! do
          :stop if @cost
        end
      end
    end
  end
end
