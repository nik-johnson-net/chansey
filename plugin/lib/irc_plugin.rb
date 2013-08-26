# encoding: utf-8
require 'set'

module Chansey
    class Plugin
        module IRCPlugin
            CHANNEL_PREFIXES = [ '&', '#', '+', '!' ].to_set

            # Represents a command request
            class Request
                attr_reader :channel
                attr_reader :network
                attr_reader :command
                attr_reader :nick
                attr_reader :user
                attr_reader :host
                attr_reader :middle
                attr_reader :event
                attr_reader :arg
                attr_reader :pm

                def initialize(command, event, plugin)
                    @plugin = plugin
                    @event = event
                    @network = event['data']['network']
                    @command = command
                    @arg = event['data']['msg']['params'].partition(' ').last
                    @nick = event['data']['msg']['nick']
                    @user = event['data']['msg']['user']
                    @host = event['data']['msg']['host']
                    @middle = event['data']['msg']['middle']
                    
                    destination = @middle.first
                    if CHANNEL_PREFIXES.include? destination[0]
                        @channel = destination
                        @pm = false
                    else
                        @channel = @nick
                        @pm = true
                    end
                end
                alias pm? pm

                def notice(msg)
                    @plugin.notice(@network, @channel, msg)
                end

                def say(msg)
                    @plugin.privmsg(@network, @channel, msg)
                end

                def leave_channel(msg=nil)
                    @plugin.part(@network, @channel, msg)
                end

                def change_nick(nick)
                    @plugin.nick(@network, nick)
                end

                def quit_network(msg=nil)
                    @plugin.quit(@network, msg)
                end

                def change_topic(topic)
                    @plugin.topic(@network, @channel, topic)
                end
            end # request

            def self.included(mod)
                mod.initializer do
                    @_irc_command_map = {}
                    @irc_command_key = @config['irc']['command_key']
                    add_event_callback(&method(:_irc_event))
                    listen_for 'irc.privmsg'
                end
            end

            def _irc_event(metadata, event)
                return unless event['service'] == 'irc'

                cmd = extract_irc_command(event)
                if cmd && cmd = @_irc_command_map[cmd.downcase]
                    cmd.fire(event)
                end
            end

            # Requests
            def raw(network, line)
                rpc('irc', 'raw', {
                    :network => network,
                    :line => line
                })
            end

            def nick(network, nick)
                rpc('irc', 'nick', {
                    :network => network,
                    :nick => nick
                })
            end

            def join(network, *channels)
                mapping = {}
                channels.each { |x|
                    mapping[x] = ''
                }
                rpc('irc', 'join', {
                    :network => network,
                    :channels => mapping
                })
            end

            def part(network, channels, msg=nil)
                if channels.class == String
                    channels = [channels]
                end
                opts = {
                    :network => network,
                    :channels => channels
                }
                opts[:msg] = msg if msg

                rpc('irc', 'part', opts)
            end

            def mode(network, channel, modes, operands=nil)
                opts = {
                    :network => network,
                    :channel => channel,
                    :modes => modes
                }
                opts[:operands] = operands if operands
                rpc('irc', 'mode', opts)
            end

            def topic(network, channel, topic)
                rpc('irc', 'topic', {
                    :network => network,
                    :channel => channel,
                    :topic => topic
                })
            end

            def invite(network, channel, nick)
                rpc('irc', 'invite', {
                    :network => network,
                    :channel => channel,
                    :nick => nick
                })
            end

            def kick(network, channels, nicks)
                raise "Not Implemented"
            end

            def privmsg(network, channel, msg)
                rpc('irc', 'privmsg', {
                    :network => network,
                    :channel => channel,
                    :msg => msg
                })
            end

            def notice(network, channel, msg)
                rpc('irc', 'notice', {
                    :network => network,
                    :channel => channel,
                    :msg => msg
                })
            end

            def quit(network, msg=nil)
                opts = {:network => network}
                opts[:msg] = msg if msg
                rpc('irc', 'quit', opts)
            end

            private
            def irc_command(trigger, opts={}, &block)
                trigger.downcase!
                return nil unless @_irc_command_map[trigger].nil?

                cmd = Command.new(@log, trigger, self, opts, &block)
                @_irc_command_map[trigger] = cmd;
            end

            def extract_irc_command(event)
                return nil unless event['event'] == 'privmsg'
                return nil unless event['data']['msg']['command'] == 'privmsg'

                line = event['data']['msg']['params']
                first_word = line.partition(' ').first
                if first_word.start_with? @irc_command_key
                    return first_word[@irc_command_key.length..-1]
                else
                    return nil
                end
            end

            class Command
                attr_reader :command
                attr_reader :public
                attr_reader :private

                def initialize(log, command, plugin, opts={}, &block)
                    opts.default!({
                        :pub => true,
                        :priv => true 
                    })

                    @log = log
                    @command = command
                    @action = block
                    @public = opts[:pub]
                    @private = opts[:priv]
                    @plugin = plugin
                end

                def fire(event)
                    request = IRCPlugin::Request.new(@command, event, @plugin)
                    if (request.pm? && @private) || (!request.pm? && @public)
                        @log.debug "Calling command #{@command} (pm: #{request.pm?})"
                        @action.call( request )
                    end
                end
            end # Command
        end # IRCPlugin
    end # plugin
end # chansey

class Hash
    def default!(defaults={})
        replace(defaults.merge(self))
    end
end
