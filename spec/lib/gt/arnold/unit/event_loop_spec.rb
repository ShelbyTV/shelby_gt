require 'spec_helper'

require 'event_loop'

# UNIT test
describe GT::Arnold::EventLoop do
  
  context "pulling jobs" do
    
    it "should return true if fibers < max" do
      GT::Arnold::EventLoop.should_pull_a_job(mock_model("Mfibers", :size => 10), 11).should == true
    end
    
    it "should sleep and return false if fibers >= max" do
      EventMachine::Synchrony.stub(:sleep).with(1).and_return(true)
      GT::Arnold::EventLoop.should_pull_a_job(mock_model("Mfibers", :size => 11), 11).should == false
    end
    
  end
  
  context "wait until done" do
    
    it "should return if fibers empty" do
      GT::Arnold::EventLoop.wait_until_done(mock_model("Mfibers", :empty? => true), 1.minute.from_now).should == nil
    end
    
    it "should return if it's past kill time" do
      GT::Arnold::EventLoop.wait_until_done(mock_model("Mfibers", :empty? => false), 1.minute.ago).should == nil
    end
    
    it "should sleep and run again if fibers aren't empty and it's before kill time" do
      EventMachine::Synchrony.stub(:sleep).and_return(true)
      
      # First iteration, Time.now == 10 < 15, so it should run recursively
      Time.stub(:now).and_return(10)
      
      # Recursive iteration, Time.now == 20 > 15, so it should return
      Time.stub(:now).and_return(20)
      
      GT::Arnold::EventLoop.wait_until_done(mock_model("Mfibers", :empty? => false), 15).should == nil
    end
    
  end
  
  context "stop EM" do
    
    it "should wait, then ask EM to stop" do
      GT::Arnold::EventLoop.stub(:wait_until_done).with(:fibers, :kill).and_return(true)
      EventMachine.stub(:stop)
      GT::Arnold::EventLoop.stop_em(:fibers, :kill)
    end
    
  end
  
end