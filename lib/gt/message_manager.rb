module GT
  class MessageManager
    
    # creates a valid message, but it is not persisted to database here. 
    #  that is left for another manager...
    def self.create_message(options)
      raise ArgumentError, "must supply a :creator" unless (creator = options.delete(:creator)).is_a? User
      raise ArgumentError, "must supply :public" unless (public = options.delete(:public)).is_a? (TrueClass or FalseClass)
      
      # if there is no text, no biggie, just return nil as the message
      text = options.delete(:text)
      
      if text
        message = Message.new
        message.public = public
        message.nickname = creator.nickname
        message.realname = creator.name
        message.user_image_url = creator.user_image
        message.text = text
      else
        message = nil
      end
      
      return message 
    end
    
  end
end