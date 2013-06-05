# encoding: utf-8

module Chansey
    class Plugin
        module IRCPlugin
            # Represents a command request
            class Request
                attr_reader :channel
                attr_reader :network
                attr_reader :command
                attr_reader :event
                attr_reader :arg
                attr_reader :pm

                def initialize(command, event, plugin)
                    @plugin = plugin
                    @event = event
                    @network = event['data']['network']
                    @command = command
                    @arg = event['data']['msg']['params'].partition(' ').last
                    
                    if event['data']['msg']['middle'].first[0].match(/[[:punct:]]/)
                        @channel = event['data']['msg']['middle'].first
                        @pm = false
                    else
                        @channel = event['data']['msg']['nick']
                        @pm = true
                    end
                end
                alias pm? pm

                def reply_notice(msg)
                    @plugin.notice(@network, @channel, msg)
                end

                def reply_privmsg(msg)
                    @plugin.notice(@network, @channel, msg)
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
                    @_command_map = {}
                    @command_key = @config['irc']['command_key']
                    add_event_callback(&method(:_irc_event))
                    listen_for 'irc.privmsg'
                end
            end

            def _irc_event(metadata, event)
                return unless event['service'] == 'irc'

                cmd = extract_command(event)
                if cmd and cmd = @_command_map[cmd]
                    if event['data']['msg']['middle'][0][0] == '#' and cmd.public
                        @log.debug "Firing public event #{cmd.command}"
                        cmd.fire(event)
                    elsif cmd.private
                        @log.debug "Firing private event #{cmd.command}"
                        cmd.fire(event)
                    end
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

            def join(network, channels)
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
                return nil unless @_command_map[trigger].nil?

                cmd = Command.new(trigger, self, opts, &block)
                @_command_map[trigger] = cmd;
            end

            def extract_command(event)
                return nil unless event['event'] == 'privmsg'
                return nil unless event['data']['msg']['command'] == 'privmsg'

                line = event['data']['msg']['params']
                first_word = line.split.shift
                if first_word.start_with? @command_key
                    return first_word[@command_key.length..-1]
                else
                    return nil
                end
            end

            class Command
                attr_reader :command
                attr_reader :public
                attr_reader :private

                def initialize(command, plugin, opts={}, &block)
                    opts.default!({
                        :pub => true,
                        :priv => false
                    })

                    @command = command
                    @action = block
                    @public = opts[:pub]
                    @private = opts[:priv]
                    @plugin = plugin
                end

                def fire(event)
                    if event['data']['msg']['middle'].first[0].match(/[[:punct:]]/)
                        channel = event['data']['msg']['middle'].first
                        pm = false
                    else
                        channel = event['data']['msg']['nick']
                        pm = true
                    end

                    network = event['data']['network']
                    msg = event['data']['msg']

                    request = IRCPlugin::Request.new(@command, event, @plugin)

                    @action.call( request )
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
