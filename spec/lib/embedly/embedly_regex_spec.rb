# encoding: UTF-8

require 'spec_helper'
require 'embedly_regexes'

describe Embedly::Regexes do

  context "youtube" do

    it "should match standard URLs" do
      url = "http://youtube.com/watch/whatever"
      Embedly::Regexes.video_regexes_matches?(url).should == true
    end

  end

  context "aol" do

    it "should match standard URLs" do
      url = "http://on.aol.com/video/shaq-criticizes-dwight-howards-decision-517846622?icid=OnHomepageL1_Trending_Img"
      Embedly::Regexes.video_regexes_matches?(url).should == true
    end

  end

end