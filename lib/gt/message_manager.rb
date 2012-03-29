module GT
  class MessageManager
    
    # builds a valid message, but it is not persisted to database here. 
    #  that is left for another manager...
    def self.build_message(options)
      unless ( creator = options.delete(:creator) ) or (options.has_key?(:nickname) and options.has_key?(:realname) and options.has_key?(:user_image_url) )
        raise ArgumentError, "must supply a :creator or a :nickname, :realname, and :user_image_url"
      end
      
      raise ArgumentError, "must supply :public" unless options.has_key?(:public)
      
      # if there is no text, no biggie, just return nil as the message
      text = options.delete(:text)
      
      if text
        message = Message.new
        message.public = options[:public]
        message.nickname = options[:nickname] || creator.nickname
        message.realname = options[:realname] || creator.name
        message.user_image_url = options[:user_image_url] || creator.user_image
        message.text = text
        
        message.origin_network = options[:origin_network] if options[:origin_network]
        message.origin_id = options[:origin_id] if options[:origin_id]
        message.origin_user_id = options[:origin_user_id] if options[:origin_user_id]
      else
        message = nil
      end
      
      return message 
    end
    
  end
end