# encoding: UTF-8
require 'spec_helper' 

describe 'v1/beta_invite' do
  before(:each) do
    @u1 = Factory.create(:user)
    @pub_roll1 = Factory.create(:roll, :creator => @u1)
    @u1.public_roll = @pub_roll1
    @u1.save
  end
  
  context 'logged in' do
    before(:each) do
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end
    
    describe "POST create" do
      it "should return beta invite info on success" do
        to = "to@email.com"
        body = "the_body"
        post "/v1/beta_invite?to=#{to}&body=#{body}"
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["to_email_address"].should eq(to)
        parse_json(response.body)["result"]["email_body"].should eq(body)
      end
      
      it "should return errors when TO is left out" do
        body = "the_body"
        post "/v1/beta_invite?body=#{body}"
        response.body.should be_json_eql(409).at_path("status")
        response.body.should have_json_path("errors/beta_invite/to_email_address")
      end
      
      it "should NOT return errors when BODY is left out" do
        to = "to@email.com"
        post "/v1/beta_invite?to=#{to}"
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["to_email_address"].should eq(to)
        parse_json(response.body)["result"]["email_body"].should eq(nil)
      end
    end
    
  end
end