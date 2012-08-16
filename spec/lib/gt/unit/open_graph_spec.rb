# encoding: UTF-8

require 'spec_helper'
require 'open_graph'
require 'authentication_builder'

# UNIT test
describe GT::OpenGraph do

  before(:each) do
    @u = Factory.create(:user)
    @u.authentications.first.provider = "facebook"
    @u.save
    @u.preferences.open_graph_posting = true; @u.save

    @r = Factory.create(:roll)
    @f = Factory.create(:frame, :roll => @r)
    @m = Factory.create(:message, :user => @u)
    @c = Factory.create(:conversation, :messages => [@m], :frame_id => @f.id)
    
    @og_url = "http://shelby.tv/roll/#{@f.roll.id.to_s}/frame/#{@f.id.to_s}"
    @og_object = {:video => @og_url}
    
  end
  
  it "should post a favorite action" do
    GT::OpenGraph.stub(:post_to_og).with(@u, 'shelbytv:favorite', @og_object, nil).and_return(true)
    GT::OpenGraph.send_action('favorite', @u, @f)
  end
  
  it "should post a roll action" do
    GT::OpenGraph.stub(:post_to_og).with(@u, 'shelbytv:roll', @og_object, nil).and_return(true)
    GT::OpenGraph.send_action('roll', @u, @f)
  end
  
  it "should post a comment action" do
    GT::OpenGraph.stub(:post_to_og).with(@u, 'shelbytv:comment', @og_object, nil).and_return(true)
    GT::OpenGraph.send_action('comment', @u, @c, @m.text)
  end
  
  it "should post a share action" do
    GT::OpenGraph.stub(:post_to_og).with(@u, 'shelbytv:share', @og_object, nil).and_return(true)
    GT::OpenGraph.send_action('share', @u, @f)
  end
  
  it "should post a save action" do
    GT::OpenGraph.stub(:post_to_og).with(@u, 'shelbytv:save', @og_object, nil).and_return(true)
    GT::OpenGraph.send_action('comment', @u, @f)
  end
    
  it "should not post if user doesnt have facbeook" do
    @u.authentications.first.provider = "shelby"
    @u.save
    
    r = GT::OpenGraph.send_action('action', @u, @f)
    r.should eq(nil)
  end
  
  it "should not post if user doesnt want to" do
    @u.preferences.open_graph_posting = false; @u.save
    r = GT::OpenGraph.send_action('action', @u, @f)
    r.should eq(nil)
  end
  
  it "should return error if not given a user, action or object" do
    lambda {
      GT::OpenGraph.send_action('action', 'user', @f)
    }.should raise_error(ArgumentError)
    
    lambda {
      GT::OpenGraph.send_action(@f, 'user', @f)
    }.should raise_error(ArgumentError)
    
    lambda {
      GT::OpenGraph.send_action('action', @u, 'f')
    }.should raise_error(ArgumentError)
  end
  

end