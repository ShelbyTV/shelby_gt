# encoding: utf-8
require 'spec_helper'
require 'social_post_formatter'

describe GT::SocialPostFormatter do

  context "twitter" do
    it "should limit the number of characters in a tweet" do
      t = ""
      150.times.each {|d| t+="t"}
      
      # twitter turns all links into 22 characters, so use 22 characters below
      short_links = {"twitter" => "http://shl.by/12345678"}
      text = GT::SocialPostFormatter.format_for_twitter(t, short_links)
      (text.length <= 140).should eq(true)
    end
    
    it "should account for inline links under 22 characters" do
      t = "well... don't build your house on the other side of http://aol.com ! ➔@superdupersecret: Flying car crash-landed in roof of house"
      
      # twitter turns all links into 22 characters, so use 22 characters below
      short_links = {"twitter"=>"http://shl.by/12345678"}
      text = GT::SocialPostFormatter.format_for_twitter(t, short_links)
      (text.length <= 140).should eq(true)
    end
    
    it "should account for inline links over 22 characters" do
      t = "well... don't build your house on the other side of http://aol.com/and-this-link-is-super-long-which-is-okay-bc-it-will-be-shortened ! ➔@superdupersecret: Flying car crash-landed in roof of house"
      
      # twitter turns all links into 22 characters, so use 22 characters below
      short_links = {"twitter"=>"http://shl.by/12345678"}
      text = GT::SocialPostFormatter.format_for_twitter(t, short_links)
      (text.length == 198).should eq(true)
    end
    
  end

end
