# encoding: UTF-8
require 'api_clients/twitter_client'
require 'api_clients/twitter_info_getter'


# Handles user's automated Twitter interactions.
#
module GT
  class UserTwitterManager

    # Find all of the user's twitter friends and follow their shelby public rolls.
    # If they're a real Shelby user, they will get an email about the following.
    #
    def self.follow_all_friends_public_rolls(user)
      return unless user.has_provider? "twitter"
      self.friends_ids(user).each do |uid|
        friend = User.first( :conditions => { 'authentications.provider' => 'twitter', 'authentications.uid' => uid.to_s } )
        if friend and friend.public_roll and !user.unfollowed_roll?(friend.public_roll)
          friend.public_roll.add_follower(user)
          GT::Framer.backfill_dashboard_entries(user, friend.public_roll, 30)
        end
      end
    end

    def self.verify_auth(oauth_token, oauth_secret)
      return false unless oauth_token and oauth_secret

      begin
        c = APIClients::TwitterClient.build_for_token_and_secret(oauth_token, oauth_secret)
        #this will throw if user isn't auth'd
        c.statuses.home_timeline? :count => 1
        return true
      rescue Grackle::TwitterError
        return false
      rescue => e
        StatsManager::StatsD.increment(Settings::StatsConstants.user['verify_service']['failure']['twitter'])
        return false
      end
    end

    # if the shelby user matching twitter_uid is a faux user, make unfollowing_user unfollow them
    # returns:
    # => something truthy if the user is unfollowed
    # => false if no unfollow occurs
    def self.unfollow_twitter_faux_user(unfollowing_user, twitter_uid)
      if shelby_user_for_uid = User.first('authentications.uid' => twitter_uid, 'authentications.provider' => 'twitter')
        if shelby_user_for_uid.user_type == User::USER_TYPE[:faux]
          return shelby_user_for_uid.public_roll.remove_follower(unfollowing_user, false)
        end
      end
      return false
    end

    # update the user's Twitter avatar with the image url pased in
    def self.update_user_twitter_avatar(u, new_avatar_image)
      fields_to_update = {'authentications.$.image' => new_avatar_image}

      # if the user's existing user_image is from twitter, update it with the new one
      user_image_from_twitter = (Settings::Twitter.twitter_avatar_url_regex.match(u.user_image) || Settings::Twitter.twitter_default_avatar_url_regex.match(u.user_image))
      if user_image_from_twitter
        fields_to_update[:user_image] = new_avatar_image
        fields_to_update[:user_image_original] = new_avatar_image.gsub("_normal", "")
      end

      User.collection.update({
        'authentications.uid' => u.authentications.to_ary.find{ |a| a.provider == 'twitter'}.uid, 'authentications.provider' => 'twitter'
      },{
        :$set => fields_to_update
      })
    end

    # loop through all of our users who have twitter auth objects and update their twitter avatars
    # --options--
    #
    # :limit => Integer --- OPTIONAL maximum number of users to process
    def self.update_all_twitter_avatars(options={})
      defaults = {
        :limit => 0
      }
      options = defaults.merge(options)

      # keep some stats on our processing and return them at the end
      response = {
        :users_with_twitter_auth_found => 0,
        :users_with_valid_oauth_creds_found => 0,
        :users_without_valid_oauth_creds_found => 0,
        :users_with_valid_oauth_creds_updated => 0,
        :users_without_valid_oauth_creds_updated => 0
      }

      # we'll keep track of twitter uids for whom we don't have oauth creds to be handled in a different way
      # to avoid rate limiting
      non_oauthed_users = {}
      User.collection.find(
        {:$and => [
            {:_id => {:$lte => BSON::ObjectId.from_time(Time.at(Time.now.utc.to_f.ceil))}},
            {'authentications.provider' => 'twitter'}
          ]
        },
        {
          :limit => options[:limit],
          :timeout => false,
          :fields => ["authentications", "user_image"]
        }
      ) do |cursor|
        cursor.each do |doc|
          user = User.load(doc)

          response[:users_with_twitter_auth_found] += 1
          begin
            user_twitter_auth = user.authentications.to_ary.find{ |a| a.provider = 'twitter'}
            unless user_twitter_auth.oauth_token.nil? || user_twitter_auth.oauth_secret.nil?
              Rails.logger.info("Examining a user with oauth creds")
              # if we can oauth on behalf of the user, just lookup and update their info now as we don't have any
              # rate limiting concerns
              twitter_info_getter = APIClients::TwitterInfoGetter.new(user)
              begin
                new_avatar_image = twitter_info_getter.get_user_info.profile_image_url
              rescue Grackle::TwitterError => e
                if e.status == 429
                  Rails.logger.info('WE GOT RATE LIMITED PER USER')
                  response[:users_with_valid_oauth_creds_found] += 1
                  return response
                elsif e.response_object.errors && e.response_object.errors.any?{ |err| err.code == 89}
                  Rails.logger.info("User oauth creds invalid, will process later with application auth")
                  response[:users_without_valid_oauth_creds_found] += 1
                  non_oauthed_users[user_twitter_auth.uid] = user
                  next
                else
                  Rails.logger.info("TWITTER EXCEPTION: #{e}")
                  response[:users_with_valid_oauth_creds_found] += 1
                  next
                end
              else
                response[:users_with_valid_oauth_creds_found] += 1
              end
              Rails.logger.info("User oauth creds valid, updating now")
              self.update_user_twitter_avatar(user, new_avatar_image)
              response[:users_with_valid_oauth_creds_updated] += 1
            else
              response[:users_without_valid_oauth_creds_found] += 1
              non_oauthed_users[user_twitter_auth.uid] = user
            end
          rescue => e
            Rails.logger.info("GENERAL EXCEPTION: #{e}")
            next
          end
        end
      end

      #we're done with the users we have twitter oauth creds for, now handle the ones we don't
      unless non_oauthed_users.empty?
        Rails.logger.info("We have #{response[:users_without_valid_oauth_creds_found]} users without valid oauth creds to process in slices")

        twitter_client_for_app = APIClients::TwitterClient.build_for_app

        # we can get info for many users per call from /users/lookup
        non_oauthed_users.each_slice(Settings::Twitter.user_lookup_slice_size) do |slice|
          Rails.logger.info("Processing a slice of users without valid oauth creds")
          begin
            result = twitter_client_for_app.users.lookup!(:user_id => slice.map{ |uinfo| uinfo[0] }.join(','), :include_entities => false)
          rescue Grackle::TwitterError => e
            if e.status == 429
              Rails.logger.info('WE GOT RATE LIMITED PER APP')
              return response
            else
              Rails.logger.info("TWITTER EXCEPTION: #{e}")
              next
            end
          end
          # loop through the user info structures we got back from twitter and update avatars for the corresponding
          # shelby users
          result.each do |twitter_struct|
            begin
              Rails.logger.info("--> Processing a user from the slice")
              self.update_user_twitter_avatar(non_oauthed_users[twitter_struct.id_str], twitter_struct.profile_image_url)
              response[:users_without_valid_oauth_creds_updated] += 1
            rescue => e
              Rails.logger.info("GENERAL EXCEPTION: #{e}")
              next
            end
          end
        end

      end

      return response

    end

    private

      def self.friends_ids(user)
        begin
          APIClients::TwitterInfoGetter.new(user).get_following_ids
        rescue => e
          Rails.logger.error "[GT::UserTwitterManager] Error getting Twitter friends of user (#{user.id}): #{e}"
        end
      end

  end
end
