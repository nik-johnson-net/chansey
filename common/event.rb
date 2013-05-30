module Chansey
    module Common
        class EventIdGenerator
            PER_SECOND_DIGITS = 3

            def initialize
                @last_time_stamp = {
                    :timestamp => Time.now.to_i,
                    :counter => 0
                }
            end

            def new_id
                timestamp = Time.now.to_i
                if timestamp == @last_time_stamp[:timestamp]
                    @last_time_stamp[:counter] += 1
                else
                    @last_time_stamp[:timestamp] = timestamp
                    @last_time_stamp[:counter] = 0
                end
                id = "%d%d%0#{PER_SECOND_DIGITS}d" % [ Process.pid, timestamp, @last_time_stamp[:counter] ]
                id.to_i
            end
        end

        class EventGenerator
            def initialize(service)
                @ids = EventIdGenerator.new
                @service_name = service
            end

            def event(event, data={})
                {
                    :type => 'event',
                    :timestamp => Time.now.to_i,
                    :id => @ids.new_id,
                    :service => @service_name,
                    :event => event,
                    :data => data
                }
            end
        end
    end
end
