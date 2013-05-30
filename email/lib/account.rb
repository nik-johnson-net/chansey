require 'em-imap'


# Convert into a more usable form
# Hash => {
#   "header" => "data",
#   :body    => "Quick brown fox\r\n",
#   :seqno   => 0
#   }
class Array
    def emails_to_hashes!
        map! do |e|
            raise ValueError unless e.class == Net::IMAP::FetchData

            headers = e.attr[Chansey::Email::Account::HEADER_SEARCH].split("\r\n")
            headers.map! do |x|
                x = x.split(':').map { |y| y.strip }
                x[0] = x[0].downcase.to_sym
                x[1].gsub!(/^.*<((?:\w|[._+])+@(?:\w|[._+])+)>$/, '\1') if [:to, :from].include? x[0]
                x
            end

            hash_object = Hash[*headers.flatten]
            hash_object[:seqno] = e.seqno
            hash_object[:body] = e.attr[Chansey::Email::Account::BODY_SEARCH].rstrip
            hash_object
        end
    end
end

module Chansey
    module Email
        class Account
            HEADER_SEARCH = 'BODY[HEADER.FIELDS (SUBJECT TO FROM)]'
            BODY_SEARCH = 'BODY[1]'

            def initialize(log, account, server, port=993, ssl=true, &block)
                @log = log
                @account = account
                @processor = block

                @imap = EM::IMAP.new(server, port, ssl)
            end


            ##
            # Wraps the login process, since the code is ugly.
            # The callback calls the method to handle unread inbox messages,
            # and then start idling when thats complete.

            def login(password)
                @imap.connect.bind! do
                    send_login(password)
                end.callback do
                    @log.info "Logged in to #{@account}"

                    yield if block_given?
                end.errback do |error|
                    @log.warn "Failed to log in to #{@account}: #{error}"
                end
            end


            def process_email(from, to, subject, body)
                @log.debug "Processing email in #{@account}: From: #{from}, To: #{to}, Subject: #{subject}, Body: #{body}"
                @processor.call from, to, subject, body
            end

            ##
            # Sends the login command. 

            def send_login(password)
                @log.debug "Logging in to #{@account}..."
                @imap.login(@account, password)
            end


            ##
            # Wraps setting up a push notification handler

            def idle(&block)
                @log.debug "Starting IDLE in #{@account}"
                @imap.wait_for_new_emails do |response|
                    @log.debug "New email pushed in #{@account}: #{response}"
                    @imap.fetch(response.data, "(#{HEADER_SEARCH} #{BODY_SEARCH})").bind! do |emails|
                        emails.emails_to_hashes!

                        emails.each do |e|
                            yield e[:from], e[:to], e[:subject], e[:body]
                        end
                        @imap.store( emails.map { |x| x[:seqno] }, '+FLAGS', [:deleted] ).errback do |error|
                            @log.debug "Couldn't delete emails in #{@account}: #{error}"
                        end
                    end.bind! do 
                        @imap.expunge
                    end.errback do |error|
                        @log.debug "Error fetching emails #{@account}: #{error}"
                    end
                end
            end



            ##
            # Handles unread emails. Returns a deferrable
            # 
            #  1. select the inbox
            #  2. find all unseen messages (Unread)
            #  3. fetch the text/plain body of those emails
            #  4. process
            #  5. set the deletion flag
            #  6. expunge to trigger deletion

            def handle_unread_emails(&block)
                @log.debug "Fetching emails in #{@account}"
                @imap.select('INBOX').bind! do
                    @imap.search('UNSEEN')
                end.bind! do |email_seq|
                    @imap.fetch(email_seq, "(#{HEADER_SEARCH} #{BODY_SEARCH})") unless email_seq.empty?
                end.bind! do |emails|
                    next if emails.nil?
                    emails.emails_to_hashes!

                    emails.each do |e|
                        yield e[:from], e[:to], e[:subject], e[:body]
                    end

                    @imap.store( emails.map { |x| x[:seqno] }, '+FLAGS', [:deleted] ).errback do |error|
                        @log.debug "Couldn't delete emails in #{@account}: #{error}"
                    end
                end.bind! do 
                    @imap.expunge
                end.errback do |error|
                    @log.debug "Error fetching emails #{@account}: #{error}"
                end
            end
        end
    end
end
