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
        data = present(explain)
        explain["tags"].each do |tag|
          body << @templates[tag]["title"]
          body << ": "
          body << render_template(@templates[tag]["summary"], data)
          body << "\n"
        end

        body
      end

      protected

      def render_template(template, data)
        rendered = template.gsub(VAR_PATTERN) do
          data[$1]
        end
        # convert to markdown
        rendered.gsub!(/<\/?b>/, "**")
        rendered
      end

      def present(explain)
        used_key_parts = explain["used_key_parts"] || []

        { "table"       => explain["table"],
          "table_size"  => explain["table_size"],
          "key"         => explain["key"],
          "return_size" => explain["return_size"],
          "key_parts"   => used_key_parts.join(","),
          "cost"        => cost(explain)
        }
      end

      def cost(explain)
        percentage = (explain["cost"] / explain["table_size"]) * 100.0;

        if explain["cost"] > 100 && percentage > 1
          "#{percentage.floor}% (#{explain["cost"]}) of the"
        else
          explain["cost"]
        end
      end

    end
  end
end