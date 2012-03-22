# Background processing for the API Rails app via EventMachine
#
# Any fire-and-forget calls that will delay an API return should be pushed off to EM like this:
# EM.next_tick { this_will_take(3.seconds) }
#
# N.B. Using EM is much less to maintain than a job queue and works especially well for our current needs.
# But this may not work well for very long lived or intensive jobs that needs to be farmed out.
# In those cases we may still need to pull in a job queue.
#
module ShelbyGT_EM
  def self.start
    if defined?(PhusionPassenger)
      PhusionPassenger.on_event(:starting_worker_process) do |forked|
        if forked && EM.reactor_running?
          EM.stop
        end
        Thread.new { EM.run }
        die_gracefully_on_signal
      end
    end
  end

  def self.die_gracefully_on_signal
    Signal.trap("INT")  { EM.stop }
    Signal.trap("TERM") { EM.stop }
  end
end

# Will only run our EM if PhusionPassenger is defined, so this won't interfere w/ Arnold.
ShelbyGT_EM.start