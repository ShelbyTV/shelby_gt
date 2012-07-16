# The first Shelby (aka NOS) created one broadcast per user per social update seen for that user.
# The user model itself stored an array of broadcasts to like and watch later.
#
# This utility pulls the broadcasts from those arrays and adds them to the users new GT rolls, setting the _id appropriatley
#  so the creation time of the new Frames is the same as the original broadcast.

require 'video_manager'

module GT
  class NOSDataMigrater
  
    def self.migrate_likes_and_watch_later_for(user)
      migrate_likes_for(user)
      migrate_watch_later_for(user)
    end
  
    def self.migrate_likes_for(user)
      puts "migrating likes for #{user.nickname}..."
      self.migrate_broadcasts(user, user.liked_broadcasts, user.upvoted_roll)
    end
  
    def self.migrate_watch_later_for(user)
      puts "migrating watch later for #{user.nickname}..."
      self.migrate_broadcasts(user, user.watch_later_broadcasts, user.watch_later_roll)
    end

    def self.migrate_broadcasts(user, broadcasts_array, destination_roll)
      broadcasts_collection = User.collection.db['broadcasts']
    
      broadcasts_array.each_with_index do |bcast_id, n|
        # get a hash of the old NOS Broadcast object directly from mongo driver (will need to translate abbreviations later)
        bcast_hash = broadcasts_collection.find({:_id => bcast_id}).first
      
        if bcast_hash.blank?
          puts "ERROR: couldn't find broadcast #{bcast_id}"
          next
        end
        print 'b'
      
      
      
        #---------------------- VIDEO ------------------------
      
        #key :video_id_at_provider,    String, :abbr => :s
        #key :video_provider_name,     String, :abbr => :r
        unless video = Video.where(:provider_name => bcast_hash["r"], :provider_id => bcast_hash["s"]).first
          #key :video_source_url,        String, :abbr => :f
          unless video = GT::VideoManager.get_or_create_videos_for_url(bcast_hash["f"])
            puts "ERROR: couldn't find video for broadcast #{bcast_id}"
            next
          end
        end
        print 'v'
      
      
      
        #---------------------- MESSAGE ------------------------
      
        #key :description,         String, :abbr => :O
        #key :video_originator_user_image,         String, :abbr => :v
        #key :video_originator_user_name,          String, :abbr => :w
        #key :video_originator_user_nickname,      String, :abbr => :x
        msg = Message.new
        msg.public = true
        msg.text = bcast_hash["O"]
        msg.user_image_url = bcast_hash["v"]
        msg.realname = bcast_hash["w"]
        msg.nickname = bcast_hash["x"]
        #see if we don't get lucky with the user...
        msg.user = User.find_by_nickname(msg.nickname)
        print 'm'
      
      
      
        #---------------------- CONVERSATION ------------------------
        convo = Conversation.new
        convo.video = video
        convo.video_id = video.id
        convo.messages << msg
        convo.public = msg.public

        begin
          convo.save(:safe => true)
        rescue Mongo::OperationFailure
          # unique key failure due to duplicate
          puts "ERROR: conversation didn't save for broadcast #{bcast_id.to_s}"
          next
        end
        print 'c'
      
      

        #---------------------- FRAME ------------------------
        f = Frame.new
        #backdate to the time of the original broadcast
        f.id = BSON::ObjectId.from_time(bcast_hash["_id"].generation_time, :unique => true)
        f.creator = msg.user
        f.video = video
        f.video_id = video.id
        f.roll = destination_roll
        f.conversation = convo

        f.save

        #track the original frame in the convo
        convo.update_attribute(:frame_id, f.id)

        puts "SUCCESS: migrated broadcast #{n+1}/#{broadcasts_array.count} for #{user.nickname}"

      end
    end
  
  end
end