# Initially, the video relationship in a Conversation was not getting set properly.
# This was written to fix up all the old Conversation video references. Left checked
# in as demo code / in case it's useful in the near future.
#
# *Should only be used for DB repair/fixing* 
#
# Usage:
#   Dev::ConversationVideoFixer.fixFramesAndVideos!
#   Dev::ConversationVideoFixer.fixVideos!
#
module Dev
  class ConversationVideoFixer
    
    def self.fixVideos!
      conversationsToFix = Conversation.where(:video_id => nil)
      fixed = 1
      total = 1
      conversationsToFix.each do |c|
        if c.frame_id && BSON::ObjectId.legal?(c.frame_id.to_s)
          begin
            if f = Frame.find(c.frame_id)
              c.video_id = f.video_id
              begin
                c.save
                fixed += 1
              rescue
              end
            else
              puts "Could not find Frame..."
            end
          rescue
            puts "Exception while looking up Frame..."
          end
        end
        if total % 1000 == 0
          puts "Iterated over ~#{total} conversations"
        end
        # throttle a little bit to give the DB time to catch its breath...
        if fixed % 10000 == 0
          puts "Fixed ~#{fixed} conversations... sleep(1)"
          # hack so that we never accidentally sleep twice in a row
          fixed += 1
          sleep(1)
        end
        total += 1
      end if conversationsToFix

      puts "-----------------------------"
      puts " Total visited: ~#{total}"
      puts " Total fixed: ~#{fixed}"
      puts "-----------------------------"

    end

    def self.fixFramesAndVideos!
      while true
        begin
          conversationsToFix = Conversation.where(:video_id => nil, :frame_id => nil).skip(24)
          fixed = 1
          total = 1
          conversationsToFix.each do |c|
            begin
              first_hash = {}
              first_hash[:_id.gte] = c.id
              first_hash[:conversation_id] = c.id

              if f = Frame.first(first_hash)
                last_frame_id = f.id 
                c.frame_id = f.id
                c.video_id = f.video_id
                begin
                  c.save
                  fixed += 1
                rescue
                end
              else
                puts "Could not find Frame..."
              end
            rescue
              puts "Exception while looking up Frame..."
            end
            if total % 1000 == 0
              puts "Iterated over ~#{total} conversations"
            end
            # throttle a little bit to give the DB time to catch its breath...
            if fixed % 10000 == 0
              puts "Fixed ~#{fixed} conversations... sleep(1)"
              # hack so that we never accidentally sleep twice in a row
              fixed += 1
              sleep(1)
            end
            total += 1
          end if conversationsToFix

          puts "-----------------------------"
          puts " Total visited: ~#{total}"
          puts " Total fixed: ~#{fixed}"
          puts "-----------------------------"
        rescue
          puts "Exception; continuing to loop..."
          next
        end
        break
      end
    end

  end
end
