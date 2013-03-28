require 'spec_helper'

describe EmailWebhookController do

  describe "POST 'hook'" do
    it "returns http success" do
      post :hook
      response.should be_success
    end
  end

end
