require 'em-imap'

module Chansey
    module Email
        class Account
            def initialize(log, account, password, server, port=993, ssl=true)
                @log = log
                @account = account

                @imap = EM::IMAP.new(server, port, ssl)
                @imap.connect.bind! do
                    login(password)
                end
                .callback(&method(:callback_success))
                .errback(&method(:callback_error))
            end

            private
            def login(password)
                @log.debug "Logging in to #{@account}..."
                @imap.login(@account, password)
            end

            def callback_success(*args)
                @log.debug "Logged in to #{@account}"

                list_mailboxes
                list_sub_mailboxes
                print_unread_emails
            end

            def callback_error(error)
                @log.warn "Failed to log in to #{@account}: #{error}"
            end

            def list_mailboxes
                @log.debug "Fetching mailboxes"
                @imap.list.callback do |list|
                    @log.debug "Mailboxes: #{list.map(&:name)}"
                end.errback do |error|
                    @log.warn "Error listing mailboxes: #{error}"
                end
            end
            def list_sub_mailboxes
                @log.debug "Fetching subscribed mailboxes"
                @imap.lsub('', '').callback do |list|
                    @log.debug "Subscribed Mailboxes: #{list.map(&:name)}"
                end.errback do |error|
                    @log.warn "Error listing subscribed mailboxes: #{error}"
                end
            end

            def print_unread_emails
                @log.debug "Fetching emails"
                @imap.select('INBOX').bind! do
                    @imap.search('UNSEEN')
                end.bind! do |email_seq|
                    @imap.fetch(email_seq, 'BODY[1]') unless email_seq.empty?
                end.callback do |emails|
                    next if emails.nil?

                    emails.each do |e|
                        @log.debug "Email #{e.seqno}: #{e.attr['BODY[1]']}"
                        ### Processing goes here ###
                    end

                    @imap.store( emails.map { |x| x.seqno }, '+FLAGS', [:deleted] ).callback do
                        @log.debug "Marked emails for deletion"
                    end.errback do |error|
                        @log.debug "Couldn't delete emails: #{error}"
                    end

                    @imap.expunge
                    @imap.logout

                end.errback do |error|
                    @log.debug "Error fetching emails: #{error}"
                end
            end
        end
    end
end
