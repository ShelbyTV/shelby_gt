#
# You hate to have to write something like this, but it seems to be a fact of life.
# In testing, Arnold would run for 12-24hours (or more) without issue.  But occasionally, the
# process would appear to still be running, but hung.  No more logging, not at 0 fibers, and there
# are definately jobs in beanstalk just waiting to be crushed.
#
# So, while we still need to understand *why* the consumer fiber wasn't pulling any jobs, we can
# operate with this monitor.  If the consumer doesn't turn (i.e. get a job to do real work) within
# 1 minute, we try to gracefully shut down this process.  Assuming that a monitor will re-start us.
#
# Assumptions: 
# 0) Arnold was getting hung b/c the consumer was non-fatally dead or stuck inside beanstalk.reserve()
# 1) beanstalk treats clients in FIFO fashion, thus distributing load equally to all Arnold processes.
# 2) even at lowest volume, enough jobs will flow that each Arnold gets at least 1/min. 
#
module GT
  module Arnold
    class ConsumerMonitor
   
      def self.monitor(turn_period=5.minutes, boot_grace=1.minute)
      
        Thread.new do  
          sleep(boot_grace)
        
          Thread.current[:last_consumer_turns] = 0
          Thread.current[:suicide_time] = rand(15..25).minutes.from_now
        
          while($running) do
            sleep(turn_period)
          
            if Time.now > Thread.current[:suicide_time]
              Rails.logger.info "[Arnold::ConsumerMonitor.monitor] Killing myself b/c memory leak eventually catchs up with me.  Goodbye, world."
              self.kill_process
            elsif $consumer_turns > Thread.current[:last_consumer_turns]
              Rails.logger.debug "[Arnold::ConsumerMonitor.monitor] We're healthy.  Turns was #{Thread.current[:last_consumer_turns]} is now #{$consumer_turns}"
              Thread.current[:last_consumer_turns] = $consumer_turns  
            else
              Rails.logger.fatal "[Arnold::ConsumerMonitor.monitor] We seem hung.  Turns was #{Thread.current[:last_consumer_turns]} is now #{$consumer_turns}."
              self.kill_process
            end
          end
        
          Rails.logger.fatal "[Arnold::ConsumerMonirot.monitor] done working, thread falling through..."
        end
      
      end
    
    
      def self.kill_process
        Rails.logger.fatal "[Arnold::ConsumerMonitor.kill_process] Gracefully killing (running=false, sleep for 10s)..."
        $running = false
      
        #if EM and main thread exit gracefully, make sure to exit w/ a fail status code
        $exit_code = false
      
        #give Arnold some time to gracefully shut down
        sleep(10.seconds)
      
        if EventMachine.reactor_running?
          Rails.logger.fatal "[Arnold::ConsumerMonitor.kill_process] EM Reactor still running after 10s, forcefully killing process via Kernel.exit!(false)..."
          Kernel.exit!($exit_code)
        else
          Rails.logger.fatal "[Arnold::ConsumerMonitor.kill_process] EM Reactor stopped, exiting w/ Kernel.exit(false)..."
          Kernel.exit($exit_code)
        end
      
      end
    
    end
  end
end