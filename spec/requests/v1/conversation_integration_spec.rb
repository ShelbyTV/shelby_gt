require 'spec_helper' 

describe 'v1/conversation' do
  before(:all) do
    @u1 = Factory.create(:user)
    @c = Factory.create(:conversation)
  end
  
  context 'logged in' do
    before(:each) do
      set_omniauth()
      get '/auth/twitter/callback'
    end
    
    describe "GET" do
      it "should return conversation on success" do
        get '/v1/conversation/'+@c.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/public")
        parse_json(response.body)["result"]["public"].should eq(true)
      end
    
      it "should return error message if roll doesnt exist" do
        get '/v1/conversation/'+@c.id+'xxx'
        response.body.should be_json_eql(400).at_path("status")
      end
      
    end
    
    describe "POST" do
      it "should create and return a conversation on success" do
        params = '?text=rock%20me%20amadaeus'
        post '/v1/conversation/'+@c.id+'/messages'+params
      
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/public")
        parse_json(response.body)["result"]["messages"][0]["text"].should eq("rock me amadaeus")
      end
      
      it "should return 400 if there is no text" do
        post '/v1/conversation/'+@c.id+'/messages'
        response.body.should be_json_eql(400).at_path("status")
      end

    end
        
    describe "DELETE" do
      before(:each) do
        @m = Factory.create(:message, :text => ".evol si siht")
        @c.messages << @m
        @c.save
      end
      
      it "should delete the message from the conversation and return success" do
        delete '/v1/conversation/'+@c.id+'/messages/'+@m.id
        response.body.should be_json_eql(200).at_path("status")
      end
      
      it "should return an error if a deletion fails" do
        delete '/v1/conversation/'+@c.id+'/messages/'+@m.id+"xxx"
        response.body.should be_json_eql(400).at_path("status")
      end
      
    end
  end
  
  context "not logged in" do

    describe "All other API Routes besides GET" do
      it "should return 401 Unauthorized" do
        c = Factory.create(:conversation)
        get '/v1/conversation/'+c.id
        response.status.should eq(401)
      end
    end
    
  end
  
end