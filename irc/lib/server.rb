require 'eventmachine'

class String
    def amqp_safe
        str = ""
        each_char do |c|
            case c
            when /[0-9a-z]/
                str += c
            when /[A-Z]/
                str += "C#{c.downcase}"
            else
                str += "X#{c.unpack('C')[0].to_s(16).upcase}"
            end
        end

        return str
    end
end

class Chansey::IRC::Server < EventMachine::Connection
    # Magic regex to parse IRC according to RFC 2812
	PARSE_REGEX = /^(?>:([^! ]+)(?:(?:!([^@ ]+))?@(\S+))? )?(\w+)((?: (?![:])(?:\S)+){0,14})(?: :(.*))?$/

    # Set the timeout to detect a connection failure.
    CONNECTION_TIMEOUT = 180

	def initialize(network)
		super

		@network = network
		@bot = network.bot
        @pingtimer = EM::Timer.new(CONNECTION_TIMEOUT) { close_connection }
	end

	def receive_data(data)
        reset_timeout_timer

        begin
            unless data.force_encoding('UTF-8').valid_encoding?
                unless data.force_encoding('ISO-8859-1').valid_encoding?
                    data.force_encoding('US-ASCII')
                end
            end
            lines = parse(data)
        rescue =>e
           @bot.log.error "Parsing error: #{e.exception}: #{e.message}\nFor line: #{data}"
        else
            @network.handle_lines(lines)
        end
	end

	def connection_completed
        super
        @network.server_connected
	end

	def unbind
		@network.server_disconnected
	end

	private
	def parse(data)
		parsed_lines = []
		# Concatenate buffer and new data
		data = "#{@incomplete_line}#{data}"
		@incomplete_line = ""

		# As long as each line ends with \r\n, it is complete and ready to be
		# parsed. Otherwise add to @incomplete_line
		data.each_line do |line|
			if line[-2..-1] != "\r\n"
				@incomplete_line = line
				next
			end

			# Magic in 
			# 3...
			# 2..
			# 1.
			match = line.rstrip.match(PARSE_REGEX)
			# POOF!

			if match
				msg = {
					:nick   => match[1],
					:user   => match[2],
					:host   => match[3],
					#:command => Chansey::IRC_Numeric_Map[match[4].downcase] || match[4].downcase.to_sym,
					:command => match[4].downcase.to_sym,
					:middle => match[5].split,
					:params => match[6]
				}

				parsed_lines << msg
			else
				# Panic and submit a bug report :3
				$stderr.puts "ERROR: Line failed to parse | #{line.rstrip}"
				next
			end
		end
		
		return parsed_lines
	end

    def reset_timeout_timer
        @pingtimer.cancel
        @pingtimer = EM::Timer.new(CONNECTION_TIMEOUT) { close_connection }
    end
end
