require 'spec_helper' 

describe 'v1/gt_interest' do

  context 'creating' do
    
    describe "POST" do
      it "should return email and priority code" do
        post '/v1/gt_interest?email=spinosa@gmail.com&priority_code=TNW12'
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["email"].should eq("spinosa@gmail.com")
        parse_json(response.body)["result"]["priority_code"].should eq("TNW12")
      end
      
      it "should return email without priority code" do
        post '/v1/gt_interest?email=spinosa@gmail.com'
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["email"].should == "spinosa@gmail.com"
        parse_json(response.body)["result"]["priority_code"].should == nil
      end
      
      it "should fail without email" do
        post '/v1/gt_interest?priority_code=TNW12'
        response.body.should be_json_eql(400).at_path("status")
      end
      
    end
  end
end