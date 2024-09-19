# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `net-pop` gem.
# Please instead update this file by running `bin/tapioca gem net-pop`.


# This class is equivalent to POP3, except that it uses APOP authentication.
#
# source://net-pop/lib/net/pop.rb#729
class Net::APOP < ::Net::POP3
  # Always returns true.
  #
  # @return [Boolean]
  #
  # source://net-pop/lib/net/pop.rb#731
  def apop?; end
end

# class aliases
#
# source://net-pop/lib/net/pop.rb#737
Net::APOPSession = Net::APOP

# class aliases
#
# source://net-pop/lib/net/pop.rb#722
Net::POP = Net::POP3

# == What is This Library?
#
# This library provides functionality for retrieving
# email via POP3, the Post Office Protocol version 3. For details
# of POP3, see [RFC1939] (http://www.ietf.org/rfc/rfc1939.txt).
#
# == Examples
#
# === Retrieving Messages
#
# This example retrieves messages from the server and deletes them
# on the server.
#
# Messages are written to files named 'inbox/1', 'inbox/2', ....
# Replace 'pop.example.com' with your POP3 server address, and
# 'YourAccount' and 'YourPassword' with the appropriate account
# details.
#
#     require 'net/pop'
#
#     pop = Net::POP3.new('pop.example.com')
#     pop.start('YourAccount', 'YourPassword')             # (1)
#     if pop.mails.empty?
#       puts 'No mail.'
#     else
#       i = 0
#       pop.each_mail do |m|   # or "pop.mails.each ..."   # (2)
#         File.open("inbox/#{i}", 'w') do |f|
#           f.write m.pop
#         end
#         m.delete
#         i += 1
#       end
#       puts "#{pop.mails.size} mails popped."
#     end
#     pop.finish                                           # (3)
#
# 1. Call Net::POP3#start and start POP session.
# 2. Access messages by using POP3#each_mail and/or POP3#mails.
# 3. Close POP session by calling POP3#finish or use the block form of #start.
#
# === Shortened Code
#
# The example above is very verbose. You can shorten the code by using
# some utility methods. First, the block form of Net::POP3.start can
# be used instead of POP3.new, POP3#start and POP3#finish.
#
#     require 'net/pop'
#
#     Net::POP3.start('pop.example.com', 110,
#                     'YourAccount', 'YourPassword') do |pop|
#       if pop.mails.empty?
#         puts 'No mail.'
#       else
#         i = 0
#         pop.each_mail do |m|   # or "pop.mails.each ..."
#           File.open("inbox/#{i}", 'w') do |f|
#             f.write m.pop
#           end
#           m.delete
#           i += 1
#         end
#         puts "#{pop.mails.size} mails popped."
#       end
#     end
#
# POP3#delete_all is an alternative for #each_mail and #delete.
#
#     require 'net/pop'
#
#     Net::POP3.start('pop.example.com', 110,
#                     'YourAccount', 'YourPassword') do |pop|
#       if pop.mails.empty?
#         puts 'No mail.'
#       else
#         i = 1
#         pop.delete_all do |m|
#           File.open("inbox/#{i}", 'w') do |f|
#             f.write m.pop
#           end
#           i += 1
#         end
#       end
#     end
#
# And here is an even shorter example.
#
#     require 'net/pop'
#
#     i = 0
#     Net::POP3.delete_all('pop.example.com', 110,
#                          'YourAccount', 'YourPassword') do |m|
#       File.open("inbox/#{i}", 'w') do |f|
#         f.write m.pop
#       end
#       i += 1
#     end
#
# === Memory Space Issues
#
# All the examples above get each message as one big string.
# This example avoids this.
#
#     require 'net/pop'
#
#     i = 1
#     Net::POP3.delete_all('pop.example.com', 110,
#                          'YourAccount', 'YourPassword') do |m|
#       File.open("inbox/#{i}", 'w') do |f|
#         m.pop do |chunk|    # get a message little by little.
#           f.write chunk
#         end
#         i += 1
#       end
#     end
#
# === Using APOP
#
# The net/pop library supports APOP authentication.
# To use APOP, use the Net::APOP class instead of the Net::POP3 class.
# You can use the utility method, Net::POP3.APOP(). For example:
#
#     require 'net/pop'
#
#     # Use APOP authentication if $isapop == true
#     pop = Net::POP3.APOP($isapop).new('apop.example.com', 110)
#     pop.start('YourAccount', 'YourPassword') do |pop|
#       # Rest of the code is the same.
#     end
#
# === Fetch Only Selected Mail Using 'UIDL' POP Command
#
# If your POP server provides UIDL functionality,
# you can grab only selected mails from the POP server.
# e.g.
#
#     def need_pop?( id )
#       # determine if we need pop this mail...
#     end
#
#     Net::POP3.start('pop.example.com', 110,
#                     'Your account', 'Your password') do |pop|
#       pop.mails.select { |m| need_pop?(m.unique_id) }.each do |m|
#         do_something(m.pop)
#       end
#     end
#
# The POPMail#unique_id() method returns the unique-id of the message as a
# String. Normally the unique-id is a hash of the message.
#
# source://net-pop/lib/net/pop.rb#196
class Net::POP3 < ::Net::Protocol
  # Creates a new POP3 object.
  #
  # +address+ is the hostname or ip address of your POP3 server.
  #
  # The optional +port+ is the port to connect to.
  #
  # The optional +isapop+ specifies whether this connection is going
  # to use APOP authentication; it defaults to +false+.
  #
  # This method does *not* open the TCP connection.
  #
  # @return [POP3] a new instance of POP3
  #
  # source://net-pop/lib/net/pop.rb#417
  def initialize(addr, port = T.unsafe(nil), isapop = T.unsafe(nil)); end

  # +true+ if the POP3 session has started.
  #
  # @return [Boolean]
  #
  # source://net-pop/lib/net/pop.rb#514
  def active?; end

  # The address to connect to.
  #
  # source://net-pop/lib/net/pop.rb#490
  def address; end

  # Does this instance use APOP authentication?
  #
  # @return [Boolean]
  #
  # source://net-pop/lib/net/pop.rb#436
  def apop?; end

  # Starts a pop3 session, attempts authentication, and quits.
  # This method must not be called while POP3 session is opened.
  # This method raises POPAuthenticationError if authentication fails.
  #
  # @raise [IOError]
  #
  # source://net-pop/lib/net/pop.rb#314
  def auth_only(account, password); end

  # Deletes all messages on the server.
  #
  # If called with a block, yields each message in turn before deleting it.
  #
  # === Example
  #
  #     n = 1
  #     pop.delete_all do |m|
  #       File.open("inbox/#{n}") do |f|
  #         f.write m.pop
  #       end
  #       n += 1
  #     end
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#690
  def delete_all; end

  # Disable SSL for all new instances.
  #
  # source://net-pop/lib/net/pop.rb#463
  def disable_ssl; end

  # Yields each message to the passed-in block in turn.
  # Equivalent to:
  #
  #   pop3.mails.each do |popmail|
  #     ....
  #   end
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#668
  def each(&block); end

  # Yields each message to the passed-in block in turn.
  # Equivalent to:
  #
  #   pop3.mails.each do |popmail|
  #     ....
  #   end
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#668
  def each_mail(&block); end

  # :call-seq:
  #    Net::POP#enable_ssl(params = {})
  #
  # Enables SSL for this instance.  Must be called before the connection is
  # established to have any effect.
  # +params[:port]+ is port to establish the SSL connection on; Defaults to 995.
  # +params+ (except :port) is passed to OpenSSL::SSLContext#set_params.
  #
  # source://net-pop/lib/net/pop.rb#452
  def enable_ssl(verify_or_params = T.unsafe(nil), certs = T.unsafe(nil), port = T.unsafe(nil)); end

  # Finishes a POP3 session and closes TCP connection.
  #
  # @raise [IOError]
  #
  # source://net-pop/lib/net/pop.rb#589
  def finish; end

  # Provide human-readable stringification of class state.
  #
  # source://net-pop/lib/net/pop.rb#468
  def inspect; end

  # debugging output for +msg+
  #
  # source://net-pop/lib/net/pop.rb#715
  def logging(msg); end

  # Returns an array of Net::POPMail objects, representing all the
  # messages on the server.  This array is renewed when the session
  # restarts; otherwise, it is fetched from the server the first time
  # this method is called (directly or indirectly) and cached.
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#646
  def mails; end

  # Returns the total size in bytes of all the messages on the POP server.
  #
  # source://net-pop/lib/net/pop.rb#634
  def n_bytes; end

  # Returns the number of messages on the POP server.
  #
  # source://net-pop/lib/net/pop.rb#627
  def n_mails; end

  # Seconds to wait until a connection is opened.
  # If the POP3 object cannot open a connection within this time,
  # it raises a Net::OpenTimeout exception. The default value is 30 seconds.
  #
  # source://net-pop/lib/net/pop.rb#500
  def open_timeout; end

  # Seconds to wait until a connection is opened.
  # If the POP3 object cannot open a connection within this time,
  # it raises a Net::OpenTimeout exception. The default value is 30 seconds.
  #
  # source://net-pop/lib/net/pop.rb#500
  def open_timeout=(_arg0); end

  # The port number to connect to.
  #
  # source://net-pop/lib/net/pop.rb#493
  def port; end

  # Seconds to wait until reading one block (by one read(1) call).
  # If the POP3 object cannot complete a read() within this time,
  # it raises a Net::ReadTimeout exception. The default value is 60 seconds.
  #
  # source://net-pop/lib/net/pop.rb#505
  def read_timeout; end

  # Set the read timeout.
  #
  # source://net-pop/lib/net/pop.rb#508
  def read_timeout=(sec); end

  # Resets the session.  This clears all "deleted" marks from messages.
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#700
  def reset; end

  # source://net-pop/lib/net/pop.rb#709
  def set_all_uids; end

  # *WARNING*: This method causes a serious security hole.
  # Use this method only for debugging.
  #
  # Set an output stream for debugging.
  #
  # === Example
  #
  #   pop = Net::POP.new(addr, port)
  #   pop.set_debug_output $stderr
  #   pop.start(account, passwd) do |pop|
  #     ....
  #   end
  #
  # source://net-pop/lib/net/pop.rb#485
  def set_debug_output(arg); end

  # Starts a POP3 session.
  #
  # When called with block, gives a POP3 object to the block and
  # closes the session after block call finishes.
  #
  # This method raises a POPAuthenticationError if authentication fails.
  #
  # @raise [IOError]
  #
  # source://net-pop/lib/net/pop.rb#526
  def start(account, password); end

  # +true+ if the POP3 session has started.
  #
  # @return [Boolean]
  #
  # source://net-pop/lib/net/pop.rb#514
  def started?; end

  # does this instance use SSL?
  #
  # @return [Boolean]
  #
  # source://net-pop/lib/net/pop.rb#441
  def use_ssl?; end

  private

  # Returns the current command.
  #
  # Raises IOError if there is no active socket
  #
  # @raise [IOError]
  #
  # source://net-pop/lib/net/pop.rb#615
  def command; end

  # nil's out the:
  # - mails
  # - number counter for mails
  # - number counter for bytes
  # - quits the current command, if any
  #
  # source://net-pop/lib/net/pop.rb#599
  def do_finish; end

  # internal method for Net::POP3.start
  #
  # source://net-pop/lib/net/pop.rb#542
  def do_start(account, password); end

  # Does nothing
  #
  # source://net-pop/lib/net/pop.rb#584
  def on_connect; end

  class << self
    # Returns the APOP class if +isapop+ is true; otherwise, returns
    # the POP class.  For example:
    #
    #     # Example 1
    #     pop = Net::POP3::APOP($is_apop).new(addr, port)
    #
    #     # Example 2
    #     Net::POP3::APOP($is_apop).start(addr, port) do |pop|
    #       ....
    #     end
    #
    # source://net-pop/lib/net/pop.rb#238
    def APOP(isapop); end

    # Opens a POP3 session, attempts authentication, and quits.
    #
    # This method raises POPAuthenticationError if authentication fails.
    #
    # === Example: normal POP3
    #
    #     Net::POP3.auth_only('pop.example.com', 110,
    #                         'YourAccount', 'YourPassword')
    #
    # === Example: APOP
    #
    #     Net::POP3.auth_only('pop.example.com', 110,
    #                         'YourAccount', 'YourPassword', true)
    #
    # source://net-pop/lib/net/pop.rb#305
    def auth_only(address, port = T.unsafe(nil), account = T.unsafe(nil), password = T.unsafe(nil), isapop = T.unsafe(nil)); end

    # returns the :ca_file or :ca_path from POP3.ssl_params
    #
    # source://net-pop/lib/net/pop.rb#377
    def certs; end

    # Constructs proper parameters from arguments
    #
    # source://net-pop/lib/net/pop.rb#337
    def create_ssl_params(verify_or_params = T.unsafe(nil), certs = T.unsafe(nil)); end

    # The default port for POP3 connections, port 110
    #
    # source://net-pop/lib/net/pop.rb#210
    def default_pop3_port; end

    # The default port for POP3S connections, port 995
    #
    # source://net-pop/lib/net/pop.rb#215
    def default_pop3s_port; end

    # returns the port for POP3
    #
    # source://net-pop/lib/net/pop.rb#205
    def default_port; end

    # Starts a POP3 session and deletes all messages on the server.
    # If a block is given, each POPMail object is yielded to it before
    # being deleted.
    #
    # This method raises a POPAuthenticationError if authentication fails.
    #
    # === Example
    #
    #     Net::POP3.delete_all('pop.example.com', 110,
    #                          'YourAccount', 'YourPassword') do |m|
    #       file.write m.pop
    #     end
    #
    # source://net-pop/lib/net/pop.rb#283
    def delete_all(address, port = T.unsafe(nil), account = T.unsafe(nil), password = T.unsafe(nil), isapop = T.unsafe(nil), &block); end

    # Disable SSL for all new instances.
    #
    # source://net-pop/lib/net/pop.rb#355
    def disable_ssl; end

    # :call-seq:
    #    Net::POP.enable_ssl(params = {})
    #
    # Enable SSL for all new instances.
    # +params+ is passed to OpenSSL::SSLContext#set_params.
    #
    # source://net-pop/lib/net/pop.rb#332
    def enable_ssl(*args); end

    # Starts a POP3 session and iterates over each POPMail object,
    # yielding it to the +block+.
    # This method is equivalent to:
    #
    #     Net::POP3.start(address, port, account, password) do |pop|
    #       pop.each_mail do |m|
    #         yield m
    #       end
    #     end
    #
    # This method raises a POPAuthenticationError if authentication fails.
    #
    # === Example
    #
    #     Net::POP3.foreach('pop.example.com', 110,
    #                       'YourAccount', 'YourPassword') do |m|
    #       file.write m.pop
    #       m.delete if $DELETE
    #     end
    #
    # source://net-pop/lib/net/pop.rb#262
    def foreach(address, port = T.unsafe(nil), account = T.unsafe(nil), password = T.unsafe(nil), isapop = T.unsafe(nil), &block); end

    # source://net-pop/lib/net/pop.rb#219
    def socket_type; end

    # returns the SSL Parameters
    #
    # see also POP3.enable_ssl
    #
    # source://net-pop/lib/net/pop.rb#362
    def ssl_params; end

    # Creates a new POP3 object and open the connection.  Equivalent to
    #
    #   Net::POP3.new(address, port, isapop).start(account, password)
    #
    # If +block+ is provided, yields the newly-opened POP3 object to it,
    # and automatically closes it at the end of the session.
    #
    # === Example
    #
    #    Net::POP3.start(addr, port, account, password) do |pop|
    #      pop.each_mail do |m|
    #        file.write m.pop
    #        m.delete
    #      end
    #    end
    #
    # source://net-pop/lib/net/pop.rb#401
    def start(address, port = T.unsafe(nil), account = T.unsafe(nil), password = T.unsafe(nil), isapop = T.unsafe(nil), &block); end

    # returns +true+ if POP3.ssl_params is set
    #
    # @return [Boolean]
    #
    # source://net-pop/lib/net/pop.rb#367
    def use_ssl?; end

    # returns whether verify_mode is enable from POP3.ssl_params
    #
    # source://net-pop/lib/net/pop.rb#372
    def verify; end
  end
end

# version of this library
#
# source://net-pop/lib/net/pop.rb#198
Net::POP3::VERSION = T.let(T.unsafe(nil), String)

# source://net-pop/lib/net/pop.rb#892
class Net::POP3Command
  # @return [POP3Command] a new instance of POP3Command
  #
  # source://net-pop/lib/net/pop.rb#894
  def initialize(sock); end

  # @raise [POPAuthenticationError]
  #
  # source://net-pop/lib/net/pop.rb#914
  def apop(account, password); end

  # source://net-pop/lib/net/pop.rb#907
  def auth(account, password); end

  # source://net-pop/lib/net/pop.rb#962
  def dele(num); end

  # source://net-pop/lib/net/pop.rb#903
  def inspect; end

  # source://net-pop/lib/net/pop.rb#924
  def list; end

  # source://net-pop/lib/net/pop.rb#983
  def quit; end

  # source://net-pop/lib/net/pop.rb#955
  def retr(num, &block); end

  # source://net-pop/lib/net/pop.rb#944
  def rset; end

  # Returns the value of attribute socket.
  #
  # source://net-pop/lib/net/pop.rb#901
  def socket; end

  # source://net-pop/lib/net/pop.rb#937
  def stat; end

  # source://net-pop/lib/net/pop.rb#948
  def top(num, lines = T.unsafe(nil), &block); end

  # source://net-pop/lib/net/pop.rb#966
  def uidl(num = T.unsafe(nil)); end

  private

  # @raise [POPError]
  #
  # source://net-pop/lib/net/pop.rb#1003
  def check_response(res); end

  # @raise [POPAuthenticationError]
  #
  # source://net-pop/lib/net/pop.rb#1008
  def check_response_auth(res); end

  # source://net-pop/lib/net/pop.rb#1013
  def critical; end

  # source://net-pop/lib/net/pop.rb#994
  def get_response(fmt, *fargs); end

  # source://net-pop/lib/net/pop.rb#989
  def getok(fmt, *fargs); end

  # source://net-pop/lib/net/pop.rb#999
  def recv_response; end
end

# source://net-pop/lib/net/pop.rb#724
Net::POP3Session = Net::POP3

# POP3 authentication error.
#
# source://net-pop/lib/net/pop.rb#40
class Net::POPAuthenticationError < ::Net::ProtoAuthError; end

# Unexpected response from the server.
#
# source://net-pop/lib/net/pop.rb#43
class Net::POPBadResponse < ::Net::POPError; end

# Non-authentication POP3 protocol error
# (reply code "-ERR", except authentication).
#
# source://net-pop/lib/net/pop.rb#37
class Net::POPError < ::Net::ProtocolError; end

# This class represents a message which exists on the POP server.
# Instances of this class are created by the POP3 class; they should
# not be directly created by the user.
#
# source://net-pop/lib/net/pop.rb#744
class Net::POPMail
  # @return [POPMail] a new instance of POPMail
  #
  # source://net-pop/lib/net/pop.rb#746
  def initialize(num, len, pop, cmd); end

  # This method fetches the message.  If called with a block, the
  # message is yielded to the block one chunk at a time.  If called
  # without a block, the message is returned as a String.  The optional
  # +dest+ argument will be prepended to the returned String; this
  # argument is essentially obsolete.
  #
  # === Example without block
  #
  #     POP3.start('pop.example.com', 110,
  #                'YourAccount', 'YourPassword') do |pop|
  #       n = 1
  #       pop.mails.each do |popmail|
  #         File.open("inbox/#{n}", 'w') do |f|
  #           f.write popmail.pop
  #         end
  #         popmail.delete
  #         n += 1
  #       end
  #     end
  #
  # === Example with block
  #
  #     POP3.start('pop.example.com', 110,
  #                'YourAccount', 'YourPassword') do |pop|
  #       n = 1
  #       pop.mails.each do |popmail|
  #         File.open("inbox/#{n}", 'w') do |f|
  #           popmail.pop do |chunk|            ####
  #             f.write chunk
  #           end
  #         end
  #         n += 1
  #       end
  #     end
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#805
  def all(dest = T.unsafe(nil), &block); end

  # Marks a message for deletion on the server.  Deletion does not
  # actually occur until the end of the session; deletion may be
  # cancelled for _all_ marked messages by calling POP3#reset().
  #
  # This method raises a POPError if an error occurs.
  #
  # === Example
  #
  #     POP3.start('pop.example.com', 110,
  #                'YourAccount', 'YourPassword') do |pop|
  #       n = 1
  #       pop.mails.each do |popmail|
  #         File.open("inbox/#{n}", 'w') do |f|
  #           f.write popmail.pop
  #         end
  #         popmail.delete         ####
  #         n += 1
  #       end
  #     end
  #
  # source://net-pop/lib/net/pop.rb#861
  def delete; end

  # Marks a message for deletion on the server.  Deletion does not
  # actually occur until the end of the session; deletion may be
  # cancelled for _all_ marked messages by calling POP3#reset().
  #
  # This method raises a POPError if an error occurs.
  #
  # === Example
  #
  #     POP3.start('pop.example.com', 110,
  #                'YourAccount', 'YourPassword') do |pop|
  #       n = 1
  #       pop.mails.each do |popmail|
  #         File.open("inbox/#{n}", 'w') do |f|
  #           f.write popmail.pop
  #         end
  #         popmail.delete         ####
  #         n += 1
  #       end
  #     end
  #
  # source://net-pop/lib/net/pop.rb#861
  def delete!; end

  # True if the mail has been deleted.
  #
  # @return [Boolean]
  #
  # source://net-pop/lib/net/pop.rb#869
  def deleted?; end

  # Fetches the message header.
  #
  # The optional +dest+ argument is obsolete.
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#837
  def header(dest = T.unsafe(nil)); end

  # Provide human-readable stringification of class state.
  #
  # source://net-pop/lib/net/pop.rb#763
  def inspect; end

  # The length of the message in octets.
  #
  # source://net-pop/lib/net/pop.rb#759
  def length; end

  # This method fetches the message.  If called with a block, the
  # message is yielded to the block one chunk at a time.  If called
  # without a block, the message is returned as a String.  The optional
  # +dest+ argument will be prepended to the returned String; this
  # argument is essentially obsolete.
  #
  # === Example without block
  #
  #     POP3.start('pop.example.com', 110,
  #                'YourAccount', 'YourPassword') do |pop|
  #       n = 1
  #       pop.mails.each do |popmail|
  #         File.open("inbox/#{n}", 'w') do |f|
  #           f.write popmail.pop
  #         end
  #         popmail.delete
  #         n += 1
  #       end
  #     end
  #
  # === Example with block
  #
  #     POP3.start('pop.example.com', 110,
  #                'YourAccount', 'YourPassword') do |pop|
  #       n = 1
  #       pop.mails.each do |popmail|
  #         File.open("inbox/#{n}", 'w') do |f|
  #           popmail.pop do |chunk|            ####
  #             f.write chunk
  #           end
  #         end
  #         n += 1
  #       end
  #     end
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#805
  def mail(dest = T.unsafe(nil), &block); end

  # The sequence number of the message on the server.
  #
  # source://net-pop/lib/net/pop.rb#756
  def number; end

  # This method fetches the message.  If called with a block, the
  # message is yielded to the block one chunk at a time.  If called
  # without a block, the message is returned as a String.  The optional
  # +dest+ argument will be prepended to the returned String; this
  # argument is essentially obsolete.
  #
  # === Example without block
  #
  #     POP3.start('pop.example.com', 110,
  #                'YourAccount', 'YourPassword') do |pop|
  #       n = 1
  #       pop.mails.each do |popmail|
  #         File.open("inbox/#{n}", 'w') do |f|
  #           f.write popmail.pop
  #         end
  #         popmail.delete
  #         n += 1
  #       end
  #     end
  #
  # === Example with block
  #
  #     POP3.start('pop.example.com', 110,
  #                'YourAccount', 'YourPassword') do |pop|
  #       n = 1
  #       pop.mails.each do |popmail|
  #         File.open("inbox/#{n}", 'w') do |f|
  #           popmail.pop do |chunk|            ####
  #             f.write chunk
  #           end
  #         end
  #         n += 1
  #       end
  #     end
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#805
  def pop(dest = T.unsafe(nil), &block); end

  # The length of the message in octets.
  #
  # source://net-pop/lib/net/pop.rb#759
  def size; end

  # Fetches the message header and +lines+ lines of body.
  #
  # The optional +dest+ argument is obsolete.
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#825
  def top(lines, dest = T.unsafe(nil)); end

  # source://net-pop/lib/net/pop.rb#885
  def uid=(uid); end

  # Returns the unique-id of the message.
  # Normally the unique-id is a hash string of the message.
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#877
  def uidl; end

  # Returns the unique-id of the message.
  # Normally the unique-id is a hash string of the message.
  #
  # This method raises a POPError if an error occurs.
  #
  # source://net-pop/lib/net/pop.rb#877
  def unique_id; end
end

# source://net-pop/lib/net/pop.rb#723
Net::POPSession = Net::POP3
