require 'yaml'

module Shiba
  module Review
    class CommentRenderer
      # {{ variable }}
      VAR_PATTERN = /{{\s?([a-z_]+)\s?}}/

      def initialize(templates)
        @templates = templates
      end

      def render(explain)
        body = ""

        explain["messages"].each do |message|
          tag = message['tag']
          data = present(message)
          data.merge!(explain["global"])
          body << " * "
          body << @templates[tag]["title"]
          body << ": "
          body << render_template(@templates[tag]["summary"], data)
          body << "\n"
        end

        body << " * Estimated query time: %.2fs" % explain['cost']
        body
      end

      protected

      def render_template(template, data)
        rendered = template.gsub(VAR_PATTERN) do
          data[$1]
        end
        # convert to markdown
        rendered.gsub!(/<\/?b>/, "**")
        rendered.gsub!(/<\/?i>/, "_")
        rendered
      end

      def present(message)
        {
          "fuzz_table_sizes" => fuzzed_sizes(message),
          "table"           => message["table"],
          "table_size"      => message["table_size"],
          "index"           => message["index"],
          "join_to"         => message["join_to"],
          "key_parts"       => (message["index_used"] || []).join(','),
          "size"            => message["size"],
          "formatted_cost"  => formatted_cost(message),
          "formatted_result" => formatted_result(message)
        }
      end

      def formatted_result(explain)
        return nil unless explain['result_bytes'] && explain['result_size']

        bytes = explain['result_bytes']
        return "%d rows" % explain['result_size'] if bytes == 0

        if bytes < 1000
          result = "%d bytes" % bytes
        elsif bytes < 1000000
          result = "%dkb" % (bytes / 1000)
        else
          result = "%.1fmb" % (bytes / 1000000.0 )
        end

        "%s (%d rows)" % [result, explain['result_size']]
      end

      def formatted_cost(explain)
        return nil unless explain["rows_read"] && explain["table_size"]
        percentage = (explain["rows_read"] / explain["table_size"]) * 100.0;

        if explain["rows_read"] > 100 && percentage > 1
          "#{percentage.floor}% (#{explain["rows_read"]}) of the"
        else
          explain["rows_read"]
        end
      end

      def fuzzed_sizes(message)
        return nil unless message["tables"]
        message['tables'].group_by { |k, v| v }.map do |size, arr|
          size.to_s + ": " + arr.map(&:first).join(', ')
        end.join(". ")
      end
    end
  end
end
