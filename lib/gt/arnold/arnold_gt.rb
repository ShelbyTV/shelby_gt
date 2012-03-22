#!/usr/bin/env ruby

#TOOD: should probably set this a better way
ENV["RAILS_ENV"] ||= 'arnold'

puts "loading app..."
require File.dirname(__FILE__) + "/../../../config/application"
Rails.application.require_environment!
Rails.logger.level = 1 #0:DEBUG, 1:INFO, 2:WARN, 3:ERROR, 4:FATAL
Rails.logger.auto_flushing = true

# For cleanly exiting
$running = true
$exit_code = true
trap(:TERM) { puts "trapped SIG_TERM, stopping..."; $running = false }
trap(:INT) { puts "trapped SIG_INT, stopping..."; $running = false }


#Anything else needed
require 'arnold/event_loop'
require 'arnold/bean_job'
require 'arnold/job_processor'
require 'arnold/consumer_monitor'
require "em-synchrony"
require "em-synchrony/em-http"
# DNS resolution in Ruby is BLOCKING (even with EM), this monkeypatches things up nicely...
# We could patch EventMachine::HTTPRequest and send pull request.
require 'em-resolv-replace'
require 'em-jack'


#Our knobs to turn
$MAX_FIBERS = 1000 # <-- 1k seems to be good for LP1 (running w/ 2K hit a Segfault & deadlock in library code)
$fibers = []
$http_timeout = 60
$max_redirects = 5

#get machine name from command line options
machine = ARGV.select { |i| i =~ /^--machine_name=/ }
machine_name = (machine and machine[0].is_a? String) ? machine[0].slice(15,3) : "arnold"
#stats buckets
$statsd_job_timing_bucket = "link_processor.#{machine_name}.job_time"
$statsd_jobs_processed_bucket = "link_processor.#{machine_name}.jobs_processed"

# To make sure the consumer isn't hung, and kill ourselves if it is
$consumer_turns = 0
GT::Arnold::ConsumerMonitor.monitor()

puts "running EM..."
EventMachine.synchrony do
  Rails.logger.info "[Arnold Main] Event machine started."

  Fiber.new {
  	while($running) do
      #Make sure we don't create too many fibers
  		next unless GT::Arnold::EventLoop.should_pull_a_job($fibers, $MAX_FIBERS)
  		
  		#only counts as a turn if we're doing useful work
  	  $consumer_turns += 1

      # pull the job (w/o blocking reactor)
  		job = GT::Arnold::BeanJob.get_and_delete_job

      if job
        Rails.logger.debug "[Arnold Main] got job (job:#{job.jobid}), handing off to fiber. looks like: #{job.inspect}"
    		f = Fiber.new { |job|
    		  GT::Arnold::JobProcessor.process_job(job, $fibers, $MAX_FIBERS)
        }
        $fibers << f
        f.resume(job)
      else
        Rails.logger.debug "[Arnold Main] No job returned for processing, normal when reserving with timeout.  Looping..."
      end

  	end
  	
  	# We've been asked to exit, try to allow fibers to finish up
    Rails.logger.info "[Arnold Main] exiting..."
  	GT::Arnold::EventLoop.wait_until_done($fibers, 60.seconds.from_now)
  	Rails.logger.info "[Arnold Main] done waiting for fibers (#{$fibers.size} fibers alive), stopping event machine"
  	EventMachine.stop
  	Rails.logger.info "[Arnold Main] EventMachine.stop returned, waiting to exit loop..."
  	
  }.resume

end

puts "EM stopped, we're done"
Rails.logger.info "[Arnold Main] EventMachine loop exitied, EventMachine is stopped.  We're outta here! exit code: #{$exit_code}"
Kernel.exit($exit_code)
