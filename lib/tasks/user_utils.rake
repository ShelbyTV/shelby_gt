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

  desc "Export facebook UIDs and real user emails to three CSV files"
  task :export_facebook_uids_and_real_user_emails => :environment do

    puts "Processing users"

    processed = 0
    num_faux_uids_exported = 0
    num_real_uids_exported = 0
    num_real_emails_exported = 0

    faux_user_file = File.open(File.expand_path("~/faux_user_facebook_uids.csv"), "w")
    real_user_file = File.open(File.expand_path("~/real_user_facebook_uids.csv"), "w")
    real_user_email_file = File.open(File.expand_path("~/real_user_emails.csv"), "w")

    #can't pass :timeout => nil to find_each, so need to drop down to the driver...
    #don't want to keep running forever if users get created during the life of the cursor,
    #  so limit ourselves to records created before the cursor is started, this also causes
    #  the query to use the index on _id so that modified records won't come out of the cursor
    #  a second time
    User.collection.find({:_id => {:$lt => BSON::ObjectId.from_time(Time.now.utc)}}, {:timeout => false}) do |cursor|
      cursor.each do |hsh|
        begin
          if hsh["ac"] != User::USER_TYPE[:service]
            u = User.load(hsh)
            if u.user_type == User::USER_TYPE[:faux]
              # only export facebook uids for users with facebook auth
              if fb_auth = u.authentications.to_ary.find { |auth| auth.provider == 'facebook' }
                faux_user_file.puts(fb_auth.uid)
                num_faux_uids_exported += 1
              end
            elsif u.user_type == User::USER_TYPE[:real] || u.user_type == User::USER_TYPE[:converted]
              # only export facebook uids for users with facebook auth
              if fb_auth = u.authentications.to_ary.find { |auth| auth.provider == 'facebook' }
                real_user_file.puts(fb_auth.uid)
                num_real_uids_exported += 1
              end
              if u.primary_email && !u.primary_email.empty?
                real_user_email_file.puts(u.primary_email)
                num_real_emails_exported += 1
              end
            end
          end
        rescue Exception => e
          puts ""
          puts "[export_facebook_uids] EXCEPTION PROCESSING USER #{u.id.to_s}: #{e}"
        end
        print '.'
        processed += 1
      end
    end

    faux_user_file.close
    real_user_file.close
    real_user_email_file.close

    puts ""
    puts "Done! Processed #{processed} users"
    puts "#{num_faux_uids_exported} faux user uids were exported"
    puts "#{num_real_uids_exported} real user uids were exported"
    puts "#{num_real_emails_exported} real user emails were exported"
  end

  desc "Get facebook friend info for all current gt_enabled users that have fb authenticated"
  task :fetch_facebook_friends => :environment do

    puts "Processing users"

    @processed = 0
    @saved = 0

     User.collection.find({
      'authentications.provider' => 'facebook',
      'ag' => true
      }, {:timeout => false}) do |cursor|
      cursor.each do |hsh|
        begin
          u = User.load(hsh)
          begin
            client = GT::FacebookFriendRanker.new(u)
            friends_ranked = client.get_friends_sorted_by_rank
          rescue Koala::Facebook::APIError => e
            Rails.logger.error "[USER MANAGER ERROR] error with getting friends to rank: #{e}"
          end
          u.store_autocomplete_info(:facebook, friends_ranked) if friends_ranked
          if u.save!
            print '.'
            @saved += 1
          end
        rescue => e
          puts ""
          puts "[fetch_facebook_friends] ERROR #{u.id.to_s}: #{e}"
        end
        @processed += 1
      end
      puts "FINISHED processing #{@processed} users. #{@saved} users updated. huge success."
    end
  end

  desc "Update all users' twitter avatars"
  task :update_twitter_avatars, [:invalid_credentials_only] => [:environment] do |t, args|

    Rails.logger = Logger.new(STDOUT)

    args.with_defaults(:invalid_credentials_only => "false")

    options = {
      :invalid_credentials_only => "true".casecmp(args[:invalid_credentials_only]) == 0
    }

    action_message = "Updating user twitter avatars"
    action_message += " only for users with invalid oauth credentials" if options[:invalid_credentials_only]
    Rails.logger.info(action_message)
    result = GT::UserTwitterManager.update_all_twitter_avatars(options)
    Rails.logger.info("DONE!")
    Rails.logger.info("STATS:")
    Rails.logger.info(result)

  end

end
