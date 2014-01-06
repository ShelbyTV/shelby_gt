require 'spec_helper'
require 'apple_push_notification_services_manager'

describe GT::ApplePushNotificationServicesManager do

  context "remove_device_tokens" do
    it "loops through the users" do
      user1 = Factory.create(:user, :apn_tokens => ['<token1>', "<token3>", '<token4>'])
      user1.save
      user2 = Factory.create(:user, :apn_tokens => ['<token2>', '<token3>', '<token7>'])
      user2.save
      MongoMapper::Plugins::IdentityMap.clear

      GT::ApplePushNotificationServicesManager.remove_device_tokens(['<token1>', '<token3>'])

      MongoMapper::Plugins::IdentityMap.clear

      user1.reload
      expect(user1.apn_tokens.length).to eql 1
      expect(user1.apn_tokens).to include '<token4>'

      user2.reload
      expect(user2.apn_tokens.length).to eql 2
      expect(user2.apn_tokens).to include '<token2>'
      expect(user2.apn_tokens).to include '<token7>'
    end
  end

end