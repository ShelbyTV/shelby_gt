#
#
# Usage:
#   Dev::RollCreatorWizard.create_roll_for_user! User, title
#
module Dev
  class RollCreatorWizard

    def self.create_roll_for_user!(user, title, roll_type=Roll::TYPES[:user_public])
      raise ArgumentError, "must include a User" unless user.is_a?(User)
      raise ArgumentError, "must include a title" unless title.is_a?(String)

      # ensure user is multi roll roller
      unless user.additional_abilities.include? "multi_roll_roller"
        user.additional_abilities << "multi_roll_roller"
        user.save
      end

      # create roll
      roll = Roll.new
      roll.title = title
      roll.creator = user
      roll.roll_type = roll_type
      roll.creator_thumbnail_url = user.user_image || user.user_image_original

      begin
        roll.save!
        # user should follow roll
        roll.add_follower(user, false)
      rescue => e
        puts "[RollCreatorWizard Error] error creating new roll: #{e}"
      end
    end

  end
end
