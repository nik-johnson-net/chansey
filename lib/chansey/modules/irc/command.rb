module Chansey
  module Modules
    module Irc
      class Command
        CMD_REGEX = /\A[[:alnum:]]+\z/

        # This filter will look for PM's and assume them to contain only command args
        class DirectPrivmsgFilter
          def filter(m, ctx)
            if m[:command] == :privmsg && m[:middle][0] == ctx.nick
              command, arg = m[:trailing].split($;, 2)

              if Command.sanity_check_command(command)
                Command.new(m[:nick], command, arg, m, ctx)
              end
            end
          end
        end

        module PrefixFilter
          def prefix_filter(prefix, m, ctx)
            if m[:command] == :privmsg && m[:trailing].start_with?(prefix)
              command, arg = m[:trailing][prefix.length..-1].split($;, 2)

              if Command.sanity_check_command(command)
                reply_recipient = if m[:middle][0] == ctx.nick
                                    m[:nick]
                                  else
                                    m[:middle][0]
                                  end

                Command.new(reply_recipient, command, arg, m, ctx)
              end
            end
          end
        end

        # This filter will look for public or private messages that prefix the bot name
        class NickPrefixedPrivmsgFilter
          include PrefixFilter

          def filter(m, ctx)
            prefix = ctx.nick + ':'
            prefix_filter(prefix, m, ctx)
          end
        end

        # This filter will look for public or private messages that prefix a string
        class StrPrefixedPrivmsgFilter
          include PrefixFilter

          def initialize(prefix)
            @prefix = prefix
          end

          def filter(m, ctx)
            prefix_filter(@prefix, m, ctx)
          end
        end

        def self.sanity_check_command(string)
          if CMD_REGEX =~ string
            string
          end
        end

        attr_reader :sender
        attr_reader :command
        attr_reader :arg
        attr_reader :msg

        NOTICE = 'NOTICE %s :%s'

        def initialize(sender, command, arg, msg, connection)
          if !Command.sanity_check_command(command)
            raise ArgumentError, "Command does not match regex #{CMD_REGEX.source}"
          end

          @sender   = sender
          @command  = command
          @arg      = arg
          @msg      = msg
          @ctx      = connection
        end

        def reply(msg)
          @ctx.send_data(NOTICE % (@sender, msg))
        end
      end
    end
  end
end
