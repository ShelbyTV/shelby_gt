require 'spec_helper'

describe User do
  before(:each) do
    @user = User.new
  end
  
  it "should have an index on [nickname], [downcase_nickname], [primary_email], [authentications.uid], [authentications.nickname]" do
    indexes = User.collection.index_information.values.map { |v| v["key"] }
    indexes.should include({"nickname"=>1})
    indexes.should include({"downcase_nickname"=>1})
    indexes.should include({"primary_email"=>1})
    indexes.should include({"authentications.uid"=>1})
    indexes.should include({"authentications.nickname"=>1})
  end
  
end
