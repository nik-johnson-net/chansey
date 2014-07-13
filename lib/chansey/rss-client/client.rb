module Chansey
  module RSS
    module Client
      class Client
        DEFAULT_TIMER_SECONDS = 300

        def initialize(config, log)
          @config = config
          @log = log
          @timer = config['delay'] || DEFAULT_TIMER_SECONDS
          @next_poll = Time.now
          @feeds = @config['feeds'] || []

          schedule_poll
        end

        private
        def schedule_poll
          delay = (@next_poll - Time.now).to_i

          if delay > 0
            @log.debug "scheduling RSS poll in #{delay} seconds"
            EventMachine.add_timer(delay) do
              start_poll
            end
          else
            start_poll
          end

          nil
        end

        def start_poll
          @log.debug "Starting RSS poll"
          @feeds.each do |f|
          end

          nil
        end
      end
    end
  end
end
