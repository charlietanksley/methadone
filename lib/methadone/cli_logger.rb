require 'logger'

module Methadone
  # A Logger instance that gives better control of messaging the user
  # and logging app activity.  At it's most basic, you would use
  # #info as a replacement for +puts+ and #error as a replacement
  # for <tt>STDERR.puts</tt>.  Since this is a logger, however, you
  # can also use #debug, #warn, and #fatal, and you can control
  # the format and "logging level" as such.
  #
  # So, by default:
  # * #debug messages do not appear anywhere
  # * #info messages appear on the standard output
  # * #warn, #error, and #fata messagse appear on the standard error
  # * The default format of messages is simply the message, no logging cruft
  #
  # You can customize this in several ways:
  # 
  # * You can override the devices used by passing different devices to the constructor
  # * You can adjust the level of message that goes to the error logger via error_level=
  # * You can adjust the format for messages to the error logger separately via error_formatter=
  #
  # === Example
  #
  #     logger = CLILogger.new
  #     logger.debug("Starting up") # => only the standard output gets this
  #     logger.warn("careful!") # => only the standard error gets this
  #     logger.error("Something went wrong!") # => only the standard error gets this
  #
  #     logger = CLILogger.new
  #     logger.error_level = Logger::ERROR
  #     logger.debug("Starting up") # => only the standard output gets this
  #     logger.warn("careful!") # => only the standard OUTPUT gets this
  #     logger.error("Something went wrong!") # => only the standard error gets this
  #     
  #     logger = CLILogger.new('logfile.txt')
  #     logger.debug("Starting up") # => logfile.txt gets this
  #     logger.error("Something went wrong!") # => BOTH logfile.txt AND the standard error get this
  class CLILogger < Logger
    BLANK_FORMAT = proc { |severity,datetime,progname,msg|
      msg + "\n"
    }

    # Helper to proxy methods to the super class AND to the internal error logger
    # 
    # +symbol+:: Symbol for name of the method to proxy
    def self.proxy_method(symbol) #:nodoc:
      old_name = "old_#{symbol}".to_sym
      alias_method old_name,symbol
      define_method symbol do |*args,&block|
        send(old_name,*args,&block)
        @stderr_logger.send(symbol,*args,&block)
      end
    end

    proxy_method :'formatter='
    proxy_method :'datetime_format='

    def add(severity, message = nil, progname = nil, &block) #:nodoc:
      if @split_logs 
        unless severity >= @stderr_logger.level
          super(severity,message,progname,&block)
        end
      else
        super(severity,message,progname,&block)
      end
      @stderr_logger.add(severity,message,progname,&block)
    end
    

    # A logger that logs error-type messages to a second device; useful
    # for ensuring that error messages go to standard error.  This should be
    # pretty smart about doing the right thing.  If both log devices are
    # ttys, e.g. one is going to standard error and the other to the standard output,
    # messages only appear once in the overall output stream.  In other words,
    # an ERROR logged will show up *only* in the standard error.  If either
    # log device is NOT a tty, then all messages go to +log_device+ and only
    # errors go to +error_device+
    #
    # +log_device+:: device where all log messages should go, based on level
    # +error_device+:: device where all error messages should go.  By default, this is Logger::Severity::WARN
    def initialize(log_device=$stdout,error_device=$stderr)
      super(log_device)
      @split_logs = log_device.tty? && error_device.tty?
      self.level = Logger::Severity::INFO
      @stderr_logger = Logger.new(error_device)
      @stderr_logger.level = Logger::Severity::WARN
      self.formatter = BLANK_FORMAT if log_device.tty?
      @stderr_logger.formatter = BLANK_FORMAT if error_device.tty?
    end

    # Set the threshold for what messages go to the error device.  Note that calling
    # #level= will *not* affect the error logger
    #
    # +level+:: a constant from Logger::Severity for the level of messages that should go
    #           to the error logger
    def error_level=(level)
      @stderr_logger.level = level
    end

    # Overrides the formatter for the error logger.  A future call to #formatter= will
    # affect both, so the order of the calls matters.
    #
    # +formatter+:: Proc that handles the formatting, the same as for #formatter=
    def error_formatter=(formatter)
      @stderr_logger.formatter=formatter
    end

  end
end
