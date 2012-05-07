# encoding: UTF-8

require 'spec_helper'
require 'embedly_regexes'

describe Embedly::Regexes do

  context "youtube" do
    
    it "should match standard URLs" do
      url = "http://youtube.com/v/whatever"
      Embedly::Regexes.video_regexes_matches?(url).should == true
    end
    
  end
  
end