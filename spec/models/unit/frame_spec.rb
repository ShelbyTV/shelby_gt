require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe Frame do
  before(:each) do
    @frame = Frame.new
  end

  it "should use the database roll-frame" do
    @frame.database.name.should =~ /.*roll-frame/
  end

  context "when F1 gets re-rolled as F2:" do

    before(:each) do
      @f1 = Frame.new
      @f1.conversation = Conversation.new
      @u = User.new
      @r2 = Roll.new
      @f2 = @f1.re_roll(@u, @r2)[:frame]
    end

    it "F2 should have video from F1, blank upvoters, new conversation, updated creator, updated roll, heavy_weight share type" do
      @f2.video.should == @f1.video
      @f2.upvoters.size.should == 0
      @f2.conversation.should_not == @f1.conversation
      @f2.creator_id.should == @u.id
      @f2.roll_id.should == @r2.id
      @f2.type.should == Frame::FRAME_TYPE[:heavy_weight]
    end

    it "F1 should have F2 as its only child" do
      @f1.frame_children.should == [@f2.id]
    end

    it "F1 should have no ancestors" do
      @f1.frame_ancestors.should == []
    end

    it "F2 should have F1 as its only ancestor" do
      @f2.frame_ancestors.should == [@f1.id]
    end

    it "F2 should have no children" do
      @f2.frame_children.should == []
    end

  end

  context "when F1 gets re-rolled as F2, then F2 gets re-rolled as F3:" do

    before(:each) do
      @f1 = Frame.new
      @u = User.new
      @r2 = Roll.new
      @f2 = @f1.re_roll(@u, @r2)[:frame]
      @f3 = @f2.re_roll(@u, @r2)[:frame]
    end

    it "F1 should have F2 as its only child" do
      @f1.frame_children.should == [@f2.id]
    end

    it "F1 should have no ancestors" do
      @f1.frame_ancestors.should == []
    end

    it "F2 should have F1 as its only ancestor" do
      @f2.frame_ancestors.should == [@f1.id]
    end

    it "F2 sould have F3 as its only child" do
      @f2.frame_children.should == [@f3.id]
    end

    it "F3 should have ordered ancestors [F1, F2]" do
      @f3.frame_ancestors.should == [@f1.id, @f2.id]
    end

    it "F3 should have no children" do
      @f3.frame_children.should == []
    end

  end

  context "when F1 gets re-rolled as F2, then F1 gets re-rolled again as F3:" do

    before(:each) do
      @f1 = Frame.new
      @u = User.new
      @r2 = Roll.new
      @f2 = @f1.re_roll(@u, @r2)[:frame]
      @f3 = @f1.re_roll(@u, @r2)[:frame]
    end

    it "F1 should have ordered children [F2, F3]" do
      @f1.frame_children.should == [@f2.id, @f3.id]
    end

    it "F1 should have no ancestors" do
      @f1.frame_ancestors.should == []
    end

    it "F2 should have F1 as its only ancestor" do
      @f2.frame_ancestors.should == [@f1.id]
    end

    it "F2 should have no children" do
      @f2.frame_children.should == []
    end

    it "F3 should have F1 as its only ancestor" do
      @f3.frame_ancestors.should == [@f1.id]
    end

    it "F3 should have no children" do
      @f3.frame_children.should == []
    end

  end

end
