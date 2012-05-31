require 'spec_helper'

describe ApplicationHelper do

  context "concise_time_ago_in_words" do
    
    it "should return 'just now' for < 1 minute ago" do
      concise_time_ago_in_words(10.seconds.ago).should == "just now"
      concise_time_ago_in_words(45.seconds.ago).should == "just now"
    end
    
    it "should return 'just now' for future times" do
      concise_time_ago_in_words(11.minutes.from_now).should == "just now"
    end
    
    it "should return 'Xm' for X minutes ago up to 59" do
      concise_time_ago_in_words(3.minutes.ago).should == "3m ago"
      concise_time_ago_in_words(22.minutes.ago).should == "22m ago"
      concise_time_ago_in_words(59.minutes.ago).should == "59m ago"
    end
    
    it "should return '1h' for 1:00 - 1:59 hours ago" do
      concise_time_ago_in_words(1.hour.ago).should == "1h ago"
      concise_time_ago_in_words((1.hour + 59.minutes).ago).should == "1h ago"
    end
    
    it "should return '2h' for 2:00 - 2:29 hours ago" do
      concise_time_ago_in_words((2.hours + 0.minutes).ago).should == "2h ago"
      concise_time_ago_in_words((2.hours + 59.minutes).ago).should == "2h ago"
    end
    
    it "should return '10h' for 10:00 - 10:59 hours ago" do
      concise_time_ago_in_words((10.hours + 0.minutes).ago).should == "10h ago"
      concise_time_ago_in_words((10.hours + 59.minutes).ago).should == "10h ago"
    end
    
    it "should return '11h' for 11:00 - 11:59 hours ago" do
      concise_time_ago_in_words((11.hours + 0.minutes).ago).should == "11h ago"
      concise_time_ago_in_words((11.hours + 59.minutes).ago).should == "11h ago"
    end
    
    it "should return 'MMM dd' for > 12 hours ago" do
      concise_time_ago_in_words(13.hours.ago).should == 13.hours.ago.strftime("%b %-d")
      concise_time_ago_in_words(72.hours.ago).should == 72.hours.ago.strftime("%b %-d")
      concise_time_ago_in_words(10.days.ago).should == 10.days.ago.strftime("%b %-d")
      concise_time_ago_in_words(1000.days.ago).should == 1000.days.ago.strftime("%b %-d")
    end
    
    it "should handle shitty input" do
      concise_time_ago_in_words(nil).should == ""
      concise_time_ago_in_words(0).should == ""
      concise_time_ago_in_words(false).should == ""
    end
    
  end

end