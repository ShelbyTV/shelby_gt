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

  desc "Fix (faux, real, converted) user's public roll types"
  task :fix_public_roll_types => :environment do

    Rails.logger = Logger.new(STDOUT)

    Rails.logger.info "Fixing user public roll types"

    stats = {
      :users_examined => {},
      :users_processed => {},
      :users_fixed => {},
      :users_with_errors => {}
    }

    #can't pass :timeout => nil to find_each, so need to drop down to the driver...
    #don't want to keep running forever if users get created during the life of the cursor,
    #  so limit ourselves to records created before the cursor is started, this also causes
    #  the query to use the index on _id so that modified records won't come out of the cursor
    #  a second time
    User.collection.find(
      {
        :_id => {:$lt => BSON::ObjectId.from_time(Time.now.utc)}
      }, {
        :timeout => false,
        :fields => [:ab, :ac, :_id]
      }
    ) do |cursor|
      cursor.each do |hsh|
        begin
          Rails.logger.info "Processing user #{hsh['_id']}"
          user_type = hsh["ac"]
          stats[:users_examined][:total] = (stats[:users_examined][:total] || 0) + 1
          stats[:users_examined][hsh["ac"]] = (stats[:users_examined][hsh["ac"]] || 0) + 1
          # for now, we only fix faux, real, and converted users
          if [User::USER_TYPE[:faux], User::USER_TYPE[:real], User::USER_TYPE[:converted]].include?(hsh["ac"])
            stats[:users_processed][:total] = (stats[:users_processed][:total] || 0) + 1
            stats[:users_processed][hsh["ac"]] = (stats[:users_processed][hsh["ac"]] || 0) + 1
            u = User.load(hsh)
            if GT::UserManager.fix_user_public_roll_type(u)
              stats[:users_fixed][:total] = (stats[:users_fixed][:total] || 0) + 1
              stats[:users_fixed][hsh["ac"]] = (stats[:users_fixed][hsh["ac"]] || 0) + 1
            end
          end
        rescue Exception => e
          stats[:users_with_errors][:total] = (stats[:users_with_errors][:total] || 0) + 1
          stats[:users_with_errors][hsh["ac"]] = (stats[:users_with_errors][hsh["ac"]] || 0) + 1
          Rails.logger.info "[fix_public_roll_types] EXCEPTION PROCESSING USER #{u.id.to_s}: #{e}"
        end
      end
    end
    Rails.logger.info "Done!"
    Rails.logger.info "Stats:"
    Rails.logger.info stats

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
  task :update_twitter_avatars, [:limit] => [:environment] do |t, args|
    require 'newrelic-rake'
    NewRelic::Agent.manual_start

    Rails.logger = Logger.new(STDOUT)

    args.with_defaults(:limit => "0")

    options = {
      :limit => args[:limit].to_i
    }

    Rails.logger.info("Updating user twitter avatars")
    result = GT::UserTwitterManager.update_all_twitter_avatars(options)
    Rails.logger.info("DONE!")
    Rails.logger.info("STATS:")
    Rails.logger.info(result)

  end

  desc 'Fix all users who have inconsistencies in their avatar data'
  task :fix_inconsistent_user_images, [:limit] => [:environment] do |t, args|

    Rails.logger = Logger.new(STDOUT)

    args.with_defaults(:limit => "0")

    options = {
      :limit => args[:limit].to_i
    }

    Rails.logger.info("Fixing users")

    stats = {
      :users_examined => 0,
      :users_fixed => 0
    }

    User.collection.find(
      {
        :$and => [
          {:_id => {:$lt => BSON::ObjectId.from_time(Time.now.utc)}},
          {:user_image => {:$exists => true, :$nin => ["", nil]}}
        ]
      },
      {
        :timeout => false,
        :limit => options[:limit],
        :fields => ["authentications", "user_image", "user_image_original", "nickname"]
      }
    ) do |cursor|
      cursor.each do |doc|
        u = User.load(doc)
        stats[:users_examined] += 1
        Rails.logger.info "Examining user #{u.nickname}"
        begin
          result = GT::UserManager.fix_inconsistent_user_images(u)
          if result
            User.collection.update({:_id => u.id},
            {
              :$set => {
                :user_image => u.user_image,
                :user_image_original => u.user_image_original
              }
            })
            Rails.logger.info "User #{u.nickname} fixed"
            stats[:users_fixed] += 1
          end
        rescue Exception => e
          Rails.logger.info "EXCEPTION PROCESSING USER #{u.id.to_s}: #{e}"
        end

      end
    end
    puts "DONE!"
    puts stats

  end

end
