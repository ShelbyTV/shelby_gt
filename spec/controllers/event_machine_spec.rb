# We don't have an EventMachineController, but we are using EM to do background processing (instead of a job queue)
# And since it's the controllers that will be utilizing EM for their background processing, we'll explicity test our
# EM implementation with this special controller spec.

require 'spec_helper'

describe ShelbyGT_EM do
  # Fake the existence of PhusionPassenger and allow the EM startup block to run immediately
  # see /config/initializers/event_machine.rb
  class PhusionPassenger
    def self.on_event(event, &block)
      yield block
    end
  end

  # ---STARTUP---
  # keep these before all your tests
  context "startup" do
    it "should start" do
      ShelbyGT_EM.start
      sleep(0.3) #nope, not happy about this
      EM.reactor_running?.should == true
    end
  
    it "should be running throughout all of these tests" do
      EM.reactor_running?.should == true
    end
  end
  #--------------------------------
  
  
  context "doing actual work" do
    it "should call methods of objects in the background" do
      @some_job = mock_model("MJob")
      @some_job.should_receive(:run)
      EM.next_tick { @some_job.run }
      sleep(0.3)
    end
    
    it "should set local variables in background (though we would never do this)" do
      should_be_true = false
      EM.next_tick { should_be_true = true }
      sleep(0.3) #nope, not happy about this
      should_be_true.should == true
    end
  end
  
  
  #--------------------------------
  # ---SHUTDOWN---
  # keep these after all your tests
  context "shutdown" do
    it "should still be running after all of the tests" do
      EM.reactor_running?.should == true
    end
  
    it "should stop" do
      EM.reactor_running?.should == true
      EM.stop
      sleep(0.3) #nope, not happy about this
      EM.reactor_running?.should == false
    end
  end
end
