require 'formatted_rails_logger'

module GT
  class RailsLogFormatter
    # Unlike Logger, not seeing a need to include the PID, the progname, 
    # or the Severity twice. 
    @@format_str = "[%s] %5s  %s"
  
    def call(severity, time, progname, msg)   
      # Rails 3.2 seems to automatically add a newline, for consistency we will too. 
      msg += "\n"
    
      formatted_time = time.strftime("%Y-%m-%d %H:%M:%S.") << time.usec.to_s[0..2].rjust(3)
        
      (@@format_str % [formatted_time, severity, msg])
    end    
  
  end
end
#monkey-patch BufferedLogger
FormattedRailsLogger.patch_rails

#Use the supplied formatter that includes timestamp and severity
Rails.logger.formatter = GT::RailsLogFormatter.new