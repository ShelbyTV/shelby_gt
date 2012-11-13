module GT
  module DiscussionRollUtils
    extend ActiveSupport::Concern
    
    def find_or_create_discussion_roll_for(user, participants_string)
      return nil unless user.is_a?(User) and participants_string.is_a?(String)
      participants_array = convert_participants(participants_string)
    
      r = find_discussion_roll_for(user, participants_array)
      r ? r : create_discussion_roll_for(user, participants_array)
    end
  
    # returns a single user_discussion_roll exactly mathing user and participants, or nil if none matched
    def find_discussion_roll_for(user, participants)
      return nil unless user.is_a?(User) and participants.is_a?(Array)
    
      # Get all of this user's discussion rolls
      discussion_rolls = Roll.where(
    	  :id => user.roll_followings.map { |rf| rf.roll_id }, 
    	  :roll_type => Roll::TYPES[:user_discussion_roll] )
  	
    	# Look for a roll where the participants list matches exactly
    	matching_rolls = discussion_rolls.select do |dr|
    	  if dr.discussion_roll_participants.size == participants.size + 1
    	    dr.discussion_roll_participants - (participants + [user.id]) == []
  	    else
  	      false
	      end
  	  end
  	  
  	  Rails.logger.error "[GT::DiscussionRollUtils#find_discussion_roll_for] multiple matching rolls. User: #{user} Participatns: #{participants}" if matching_rolls.size > 1
  	  return matching_rolls[0] #nil if none matched
    end
  
    def create_discussion_roll_for(user, participants)
      return nil unless user.is_a?(User)
      
      r = Roll.new
      r.creator = user
      r.roll_type = Roll::TYPES[:user_discussion_roll]
      r.public = false
      r.collaborative = true
      r.discussion_roll_participants = ([user.id] + participants).compact.uniq
      r.title = "Video Conversation"
      return nil unless r.save
    
      # add all real users as roll followers
      participant_shelby_ids = participants.select { |p| p.is_a?(BSON::ObjectId) }
      followers = [user] + User.find(participant_shelby_ids)
      followers.each { |u| r.add_follower(u, false) }
    
      return r
    end
  
    # given a potentially sloppy comma and/or semicolon delineated string of email addresses and user names;
    # return a cleaned-up, compact, unique array of all lower case email addresses and/or user ids as strings
    # ex: [BSON::ObjectId('509bc4cd929d2446ea000001'), "spinosa@gmail.com", BSON::ObjectId("4fa39bd89a725b1f920008f3")]
    def convert_participants(participants_string)
      return nil unless participants_string.is_a?(String)
    
      participants_raw_array = participants_string.split(/[,;]/)
    
      participants = participants_raw_array.map do |p|
        p = p.downcase.strip
        user = (p.include?("@") ? User.find_by_primary_email(p) : User.find_by_downcase_nickname(p))
        user ? user.id : p.blank? ? nil : p
      end
    
      return participants.compact.uniq
    end
    
    def token_valid_for_discussion_roll?(token, roll)
      return false unless token.is_a?(String)
      roll_id = (roll.is_a?(Roll) ? roll.id.to_s : roll)
      return false unless roll_id.is_a?(String)
      
      begin
        return roll_identifier_from_token(token) == roll_id
      rescue
        return false
      end
    end

    def user_from_token(token)
      BSON::ObjectId.legal?(user_identifier_from_token(token)) ? User.find(user_identifier_from_token(token)) : nil
    end

    def email_from_token(token)
      Mail::Address.new(user_identifier_from_token(token))
    end
    
    def user_identifier_from_token(token)
      return nil unless valid_token?(token)
      decrypt_roll_user_identification(token).split("::")[1]
    end
    
    def roll_identifier_from_token(token)
      return nil unless valid_token?(token)
      decrypt_roll_user_identification(token).split("::")[0]
    end
    
    def valid_token?(token)
      token.is_a?(String) and decrypt_roll_user_identification(token).include?("::")
    end

    # WARNING: Changing these contants will make inacessible the discussion rolls for non-shelby users
    CIPHER_KEY = "\xAE\\\x04FY\xB6\xFF\xD0\x81/\xDFb\x01\xC2\xE0\xF1" 
    CIPHER_IV = "\xB2\xC0\xC2x\xBF\x1D\x1A\x19\x1E\x95\xE6\xCBl\xD6\xA2U"

    # WARNING: Changing this method will make inacessible the discussion rolls for non-shelby users
    # user_identifier is the email address for non-shelby users, the bson id for shelby users
    # returns a Base64 (strictly) encoded token
    def self.encrypt_roll_user_identification(roll, user_identifier)
      data = "#{roll.id}::#{user_identifier}"

      cipher = OpenSSL::Cipher::AES.new(128, :CBC)
      cipher.encrypt
      cipher.key = CIPHER_KEY
      cipher.iv = CIPHER_IV

      return Base64.strict_encode64(cipher.update(data) + cipher.final)
    end

    # WARNING: Changing this method will make inacessible the discussion rolls for non-shelby users
    def decrypt_roll_user_identification(base64_strict_encrypted)
      decipher = OpenSSL::Cipher::AES.new(128, :CBC)
      decipher.decrypt
      decipher.key = CIPHER_KEY
      decipher.iv = CIPHER_IV

      return decipher.update(Base64.decode64(base64_strict_encrypted.gsub(' ','+'))) + decipher.final
    end
  
  end
end