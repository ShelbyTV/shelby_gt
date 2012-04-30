require 'spec_helper'
require 'social_post_formatter'

describe GT::SocialPostFormatter do

  context "twitter" do
    it "should limit the number of characters in a tweet" do
      t = ""
      150.times.each {|d| t+="t"}
      
      short_links = {"twitter" => "http://shl.by/12345"}
      text = GT::SocialPostFormatter.format_for_twitter(t, short_links)
      (text.length <= 140).should eq(true)
    end
  end

end