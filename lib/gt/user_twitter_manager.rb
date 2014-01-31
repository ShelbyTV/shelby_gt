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
      rescue
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
      stats = {
        :users_with_twitter_auth_found => 0,
        :users_with_twitter_auth_updated => 0
      }

      # collect a pool of user oauth_creds as we go so we can use them smartly to
      # avoid rate limiting
      oauth_creds = []
      # collect users hashed by twitter uid so we can get back to the user objects once we have
      # our twitter results
      users = {}
      # keep track of how many requests we have left to make with the current set of oauth creds
      client_info = {
        :requests_left => 0,
        :twitter_client => {}
      }
      User.collection.find(
        {:$and => [
            {:_id => {:$lte => BSON::ObjectId.from_time(Time.at(Time.now.utc.to_f.ceil))}},
            {'authentications.provider' => 'twitter'}
          ]
        },
        {
          :sort => [:_id, :desc],
          :limit => options[:limit],
          :timeout => false,
          :fields => ["authentications", "user_image"]
        }
      ) do |cursor|
        cursor.each do |doc|
          user = User.load(doc)

          stats[:users_with_twitter_auth_found] += 1
          begin
            collected_user = false
            user_twitter_auth = user.authentications.to_ary.find{ |a| a.provider = 'twitter'}
            # if the user has oauth creds, collect them for smart use later
            unless user_twitter_auth.oauth_token.nil? || user_twitter_auth.oauth_secret.nil?
              oauth_creds.push({:token => user_twitter_auth.oauth_token, :secret => user_twitter_auth.oauth_secret})
            end
            users[user_twitter_auth.uid] = user
            collected_user = true
            # check if we've collected enough users to fetch a batch of info from twitter,
            # and then do so
            unless check_update_user_avatar_batch(users, oauth_creds, client_info, stats)
              # if something went drastically wrong, return immediately
              return stats
            else
            end
          rescue => e
            Rails.logger.info("GENERAL EXCEPTION, SKIPPING PROCESSING SHELBY USER #{user.id}: #{e}")
            users.delete(user_twitter_auth.uid) if collected_user
            next
          end
        end
      end

      # do one more batch for whatever users are left over
      begin
        check_update_user_avatar_batch(users, oauth_creds, client_info, stats, {:force_batch => true})
      rescue => e
        Rails.logger.info("GENERAL EXCEPTION, SKIPPING LAST BATCH: #{e}")
      end

      return stats

    end

    private

      def self.check_update_user_avatar_batch(users, oauth_creds, client_info, stats, options={})
        defaults = {
         :force_batch => false
        }
        options = defaults.merge(options)

        if (users.count == Settings::Twitter.user_lookup_batch_size) || (!users.count.zero? && options[:force_batch])
          # if we've collected the number of users we include in a batch for a twitter lookup,
          # do the lookup and update the avatars
          lookup_resolved = false
          until lookup_resolved do
            # if we don't have a twitter client with sufficient requests left, create a new one
            if (client_info[:requests_left] == 0) && (!oauth_creds.empty? || client_info[:twitter_client][:client_type] != :app)
              Rails.logger.info("Building a new twitter client")
              client_info[:twitter_client] = build_best_available_client(oauth_creds)
              # if we had to build a client with our app credentials, only use it once before
              # trying to build a client with user credentials again
              client_info[:requests_left] = (client_info[:twitter_client][:client_type] == :app) ? 1 : Settings::Twitter.user_lookup_max_requests_per_oauth
            end
            # ok, now we've got a twitter client, so lookup some info and update our user avatars
            begin
              Rails.logger.info("Looking up a batch of #{users.count} users with #{client_info[:twitter_client][:client_type]} credentials")
              result = client_info[:twitter_client][:client].users.lookup!(:user_id => users.map{ |uinfo| uinfo[0] }.join(','), :include_entities => false)
            rescue Grackle::TwitterError => e
              if e.status == 429
                # if we get rate limited, return immediately
                Rails.logger.info("WE GOT RATE LIMITED #{(client_info[:twitter_client][:client_type] == :app) ? 'PER APP' : 'PER USER'}")
                return false
              elsif e.response_object.errors && e.response_object.errors.any?{ |err| err.code == 89}
                if client_info[:twitter_client][:client_type] == :app
                  Rails.logger.info('TWITTER REPLIED INVALID CREDENTIALS TO APP-WIDE CREDENTIALS')
                  return false
                else
                  # if our user twitter credentials are invalid, mark this client as having no requests left
                  # and we'll circle around with the next set of credential available to us
                  Rails.logger.info("User twitter creds invalid, will try new creds: #{e}")
                  client_info[:requests_left] = 0
                end
              else
                Rails.logger.info("TWITTER EXCEPTION, SKIPPING BATCH: #{e}")
                lookup_resolved = true
              end
            else
              lookup_resolved = true
              # loop through the user info structures we got back from twitter and update avatars for the corresponding
              # shelby users
              result.each do |twitter_struct|
                begin
                  self.update_user_twitter_avatar(users[twitter_struct.id_str], twitter_struct.profile_image_url)
                  stats[:users_with_twitter_auth_updated] += 1
                rescue => e
                  Rails.logger.info("GENERAL EXCEPTION, SKIPPING RETURNED TWITTER USER #{twitter_struct.id_str}: #{e}")
                  next
                end
              end
            end
          end

          client_info[:requests_left] -= 1
          # we've processed all the users we found so far, don't need to hang on to them anymore
          users.clear
        end

        return true
      end

      def self.build_best_available_client(oauth_creds=[])
        result = {}

        user_oauth_creds = oauth_creds.shift
        if user_oauth_creds
          # if we have user creds available, use them
          result[:client] = APIClients::TwitterClient.build_for_token_and_secret(
            user_oauth_creds[:token],
            user_oauth_creds[:secret]
          )
          result[:client_type] = :user
        else
          # otherwise, build a client using our app credentials
          result[:client] = APIClients::TwitterClient.build_for_app
          result[:client_type] = :app
        end

        return result
      end

      def self.friends_ids(user)
        begin
          APIClients::TwitterInfoGetter.new(user).get_following_ids
        rescue => e
          Rails.logger.error "[GT::UserTwitterManager] Error getting Twitter friends of user (#{user.id}): #{e}"
        end
      end

  end
end
