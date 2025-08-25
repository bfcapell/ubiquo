module Ubiquo
  module Extensions
    module DateParser
      # Get a string for a date and return a time object
      # options[:format]: String representation (default "%d/%m/%Y")
      # options[:time_offset]: Offset to apply to parsed time
      # TODO: This should be removed in favor of I18n.parse_date
      #       currently ubiquo filter functionality rely on this method.
      def parse_date(string_date, options = {})
        return if string_date.blank?

        time_offset = options.delete(:time_offset)

        time = if [Time, ActiveSupport::TimeWithZone, Date, DateTime].any?{|klass| string_date.instance_of?(klass) }
                 string_date
               else
                 format = options.delete(:format) || "%d/%m/%Y"
                 begin
                   Date.strptime(string_date, format)
                 rescue ArgumentError, TypeError
                   return
                 end
               end

        time += time_offset if time_offset
        time
      end
    end
  end
end
