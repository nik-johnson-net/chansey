# encoding: utf-8

require 'csv'
require 'metar'

class Metar::SkyCondition
    def to_s_feet
        str = to_summary
        str += " at #{height.to_s(:units => :feet)}" if height
        return str
    end
end

class METARTranslation < Chansey::Plugin
    include Chansey::Plugin::IRCPlugin
    events 'irc.privmsg'
    AIRPORT_DATABASE = File.expand_path("../NfdcFacilities_130503.csv", __FILE__)

    def init
        @airport_map = {}
        @log.info "Loading airport mappings from #{AIRPORT_DATABASE}..."
        CSV.foreach(AIRPORT_DATABASE, :col_sep => "\t", :headers => true, :return_headers => true)do |row|
            @airport_map[row["LocationID"].gsub("'", "K")] = row["FacilityName"]
        end
        @log.info "Loaded #{@airport_map.size} translations"
    end

    def on_event(metadata, event)
        # Get arguments
        params = event['data']['msg']['params']
        destination = event['data']['msg']['middle'].first

        begin
            data = Metar::Parser.new(Metar::Raw::Data.new(params))
        rescue Metar::ParseError
            return
        end
        
        weather_string = "Weather for #{@airport_map[data.station_code] || data.station_code}: "

        # Temperature data
        weather_string += "Temperature: #{data.temperature.to_s(:units => :fahrenheit)}"
        weather_string += ", Dew Point: #{data.dew_point.to_s(:units => :fahrenheit)}" if data.dew_point
        weather_string += " - "

        # Wind data
        weather_string += "Wind: #{data.wind.to_s(:speed_units => :miles_per_hour)}"
        weather_string += " - "

        # Visibility
        weather_string += "Visibility: #{data.visibility.to_s(:units => :miles)}, "

        # HACK to get sky condition heights in feet. Need to fix source
        weather_string += "Sky: #{data.sky_conditions.map { |x| x.to_s_feet }.join(', ')}"

        # Weather
        unless data.present_weather.empty?
            weather_string += " - Weather: #{data.present_weather.join(', ')}"
        end

        privmsg(event['data']['network'],
                destination,
                weather_string)
    end
    
    private
end
