# Initially, Genius rolls/frames were created with blank conversations. That caused problems.
# This was written to delete and null out all the old Genius roll/frame conversations.
# Left checked in as demo code / in case it's useful in the near future.
#
# *Should only be used for DB repair/fixing* 
#
# Usage:
#   Dev::GeniusConversationFixer.fix!
#
module Dev
  class GeniusConversationFixer
    
    def self.fix!
      processed = 0
      while (true)
        begin
          rollsToFix = Roll.where(:genius => true).skip(processed)

          rollsToFix.each do |r|
            framesToFix = Frame.where(:roll_id => r.id)

            framesToFix.each do |f|
              if f.conversation_id
                Conversation.destroy(f.conversation_id)
                f.conversation_id = nil
                f.save
              end
            end if framesToFix

            processed += 1
 
            if processed % 10 == 0
              puts "# Processed Genius Rolls: #{processed}"
            end
          end if rollsToFix

          break

        rescue
          puts "Exception! Looping again..."
        end
      end
    end

  end
end
