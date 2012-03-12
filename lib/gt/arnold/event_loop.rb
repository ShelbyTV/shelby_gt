# Help in managing the event loop
#
module GT
  module Arnold
    class EventLoop
    
      #Make sure we only create 1,000 fibers and safely sleep for a little while if we have to
      def self.should_pull_a_job(fibers, max)
      	return true if fibers.size < max
      	Rails.logger.debug "[Arnold::EventLoop#pace_car] Too many fibers (#{fibers.size}), sleeping for 1..."
      	EventMachine::Synchrony.sleep(1)
      	Rails.logger.debug "[Arnold::EventLoop#pace_car] done sleeping."
      	return false
      end
    
    
      def self.stop_em(fibers, kill_time)
        # We've been asked to exit, try to allow fibers to finish up
        Rails.logger.info "[Arnold Main] waiting for fibers if necessary..."
      	Arnold::EventLoop.wait_until_done(fibers, kill_time)
      	Rails.logger.info "[Arnold Main] done waiting for fibers (#{fibers.size} fibers alive), stopping event machine..."
      	EventMachine.stop
      	Rails.logger.info "[Arnold Main] EventMachine.stop returned..."
      end


      def self.wait_until_done(fibers, kill_time)
      	return if fibers.empty? or Time.now > kill_time
      	Rails.logger.info "[Arnold::EventLoop#wait_until_done] still running fibers, not ready to kill, sleeping..."
      	EventMachine::Synchrony.sleep( [((kill_time - Time.now)/5).round, 1].max )
      	wait_until_done(fibers, kill_time)
      end

    end
  end
end