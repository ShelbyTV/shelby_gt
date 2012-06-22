# Initially, the video relationship in a Conversation was not getting set properly.
# This was written to fix up all the old Conversation video references. Left checked
# in as demo code / in case it's useful in the near future.
#
# *Should only be used for DB repair/fixing* 
#
# Usage:
#   Dev::ConversationVideoFixer.fix!
#
module Dev
  class ConversationVideoFixer
    
    def self.fix!
      conversationsToFix = Conversation.where(:video_id => nil)
      count = 1
      conversationsToFix.each do |c|
        if c.frame_id && BSON::ObjectId.legal?(c.frame_id.to_s)
          begin
            if f = Frame.find(c.frame_id)
              c.video_id = f.video_id
              begin
                c.save()
                count += 1
              rescue
              end
            end
          rescue
          end
        end
        # throttle a little bit to give the DB time to catch its breath...
        if count % 10000 == 0
          puts "Fixed #{count} conversations... sleep(1)"
          sleep(1)
        end
      end if conversationsToFix
    end
  end
end
