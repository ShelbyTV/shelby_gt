# encoding: UTF-8
require 'spec_helper'

describe 'v1/client_configuration' do
  
  context "not logged in" do
    
    describe "GET multivariate_tests" do
      it "should return an array of objects" do
        get 'v1/client_configuration/multivariate_tests'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(Settings::ClientConfiguration.multivariate_tests.size).at_path("result")
      end

      it "should have the proper format" do
        get 'v1/client_configuration/multivariate_tests'
        response.body.should have_json_path("result/0/name")
        response.body.should have_json_path("result/0/buckets")
        response.body.should have_json_path("result/0/buckets/0/name")
        response.body.should have_json_path("result/0/buckets/0/description")
        response.body.should have_json_path("result/0/buckets/0/active")
        # there are more parameters thatt differ per test
      end
    end
    
  end
  
end
