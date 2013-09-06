namespace :user_utils do

  desc 'Convert all NOS users to faux users'
  task :convert_nos_to_faux => :environment do

    puts "Processing users"

    processed = 0

    #can't pass :timeout => nil to find_each, so need to drop down to the driver...
    #don't want to keep running forever if users get created during the life of the cursor,
    #  so limit ourselves to records created before the cursor is started, this also causes
    #  the query to use the index on _id so that modified records won't come out of the cursor
    #  a second time
    User.collection.find({:_id => {:$lt => BSON::ObjectId.from_time(Time.now.utc)}}, {:timeout => false}) do |cursor|
      cursor.each do |hsh|
        begin
          u = User.load(hsh)
          if u.user_type == User::USER_TYPE[:real] && !u.gt_enabled
            #if it's a NOS user, convert to faux
            GT::UserManager.convert_real_user_to_faux(u)
            print '.'
          else
            #while we're at it, if they're not a NOS user, correct their app progress to the current format
            GT::UserManager.update_app_progress_onboarding(u)
            print '*'
          end
        rescue Exception => e
          puts ""
          puts "[convert_nos_to_faux] EXCEPTION PROCESSING USER #{u.id.to_s}: #{e}"
        end
        processed += 1
      end
    end
    puts ""
    puts "Done! Processed #{processed} users"

  end

  desc "Fix (for now only faux) user's public roll types"
  task :fix_public_roll_types => :environment do

    puts "Processing users"

    processed = 0
    num_faux = 0
    num_fixed = 0

    #can't pass :timeout => nil to find_each, so need to drop down to the driver...
    #don't want to keep running forever if users get created during the life of the cursor,
    #  so limit ourselves to records created before the cursor is started, this also causes
    #  the query to use the index on _id so that modified records won't come out of the cursor
    #  a second time
    User.collection.find({:_id => {:$lt => BSON::ObjectId.from_time(Time.now.utc)}}, {:timeout => false}) do |cursor|
      cursor.each do |hsh|
        begin
          # for now we're only interested in faux users
          if hsh["ac"] == User::USER_TYPE[:faux]
            num_faux += 1
            u = User.load(hsh)
            num_fixed += 1 if GT::UserManager.fix_user_public_roll_type(u)
          end
        rescue Exception => e
          puts ""
          puts "[fix_public_roll_types] EXCEPTION PROCESSING USER #{u.id.to_s}: #{e}"
        end
        print '.'
        processed += 1
      end
    end
    puts ""
    puts "Done! Processed #{processed} users, #{num_faux} were faux, #{num_fixed} had their roll types fixed"

  end

end
