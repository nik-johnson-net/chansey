# encoding: utf-8

module Chansey
    class Plugin
        module IRCPlugin
            def self.included(mod)
                @@initializers << Proc.new do
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
            def command(trigger, opts={}, &block)
                return nil unless @_command_map[trigger].nil?

                cmd = Command.new(trigger, opts, &block)
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
        end
    end
end

class Chansey::Plugin::IRCPlugin::Command
    attr_reader :command
    attr_reader :public
    attr_reader :private

    def initialize(command, opts={}, &block)
        opts.default!({
            :pub => true,
            :priv => false
        })

        @command = command
        @action = block
        @public = opts[:pub]
        @private = opts[:priv]
    end

    def fire(event)
        if event['data']['msg']['middle'].first[0].match(/[[:punct:]]/)
            destination = event['data']['msg']['middle'].first
            pm = false
        else
            destination = event['data']['msg']['nick']
            pm = true
        end

        # Signature: msg, reply_to, pm, amqp_payload
        @action.call( event['data']['msg'], destination, pm, event )
    end
end

class Hash
    def default!(defaults={})
        replace(defaults.merge(self))
    end
end
