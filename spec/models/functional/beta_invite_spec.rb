require 'spec_helper'

#Functional: hit the database, treat model as black box
describe BetaInvite do
  
  context "database" do
    
    it "should have an index on [sender_id]" do
      indexes = BetaInvite.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1})
    end

    it "should have an index on [invitee_id]" do
      indexes = BetaInvite.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"b"=>1})
    end

  end
  
end