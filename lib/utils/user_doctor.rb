# encoding: UTF-8


module GT

  class UserDoctor

    def self.clean_roll_followings(u, save=true)
      u.roll_followings.delete_if { |rf| rf.roll == nil }
      u.save if save
    end

    def self.update_rolls_metadata(u, save=true)
      u.upvoted_roll.upvoted_roll = true
      u.upvoted_roll.save if save
    end

    def self.fix_heart_roll_creators(u)
      u.upvoted_roll.frames.each do |f|
        f_ancestor = Frame.find(f.frame_ancestors.first)
        f.creator_id = f_ancestor.creator_id
        f.save
      end
    end

    def self.fix_faux_public_roll(u, save=true)
      return unless u.user_type == User::USER_TYPE[:faux]

      unless [Roll::TYPES[:special_public_upgraded], Roll::TYPES[:special_public]].include? u.public_roll.roll_type
        u.public_roll.roll_type = Roll::TYPES[:special_public]
      end
      if u.public_roll.origin_network.blank? and u.authentications[0]
        u.public_roll.origin_network = u.authentications[0].provider
      end
      u.public_roll.save if save
    end

    # For each of the user's rolls pointed to by a roll_following: make sure there's a matching following_user on the roll pointing to the user
    def self.ensure_roll_followings_mirrored(u)
      should_clean_roll_followings = false
      u.roll_followings.each do |rf|
        if rf.roll
          unless rf.roll.following_users.any? { |fu| fu.user_id == u.id }
            #User had a roll following, but the roll it pointed to DID NOT have a matching following user
            puts "User #{u.nickname} followed #{rf.roll.id}, needed mirroring following_user"
            rf.roll.push :following_users => FollowingUser.new(:user => u).to_mongo
          end
        else
          should_clean_roll_followings = true
        end
      end
      clean_roll_followings(u) if should_clean_roll_followings
    end

    def self.examine(u)
      puts "==user info=="
      puts " id         : #{u.id}"
      puts " username   : #{u.nickname}"
      puts " created at : #{u.created_at} (#{((Time.now - u.created_at) / (60*60*24)).round} days ago)"
      puts " real name  : #{u.name}"
      puts " email      : #{u.primary_email.blank? ? '*NO EMAIL*' : u.primary_email}"
      puts " auths      : #{u.authentications.count} services authenticated - #{u.authentications.map { |a| "#{a.provider} on #{a.created_at}" }.join(', ')}"
      puts " user_type  : #{User::USER_TYPE.select{|key,value| value == u.user_type}.keys[0].to_s}"
      puts " gt_enabled : #{u.gt_enabled?}"
      if u.gt_enabled?
        # rolls
        puts "  following : #{u.roll_followings.count} rolls"
        puts "  created   : #{u.roll_followings.select { |rf| rf.roll and rf.roll.creator_id == u.id and rf.roll.public } .size} public rolls"
        puts "  created   : #{u.roll_followings.select { |rf| rf.roll and rf.roll.creator_id == u.id and !rf.roll.public } .size} private rolls"

        #videos
        puts "  watched   : #{u.viewed_roll.frames.count} videos (approx.)" if u.viewed_roll
        puts "  favorited : #{u.upvoted_roll.frames.count} videos" if u.upvoted_roll
        puts "  rolled    : #{u.public_roll.frames.count} videos to their personal public roll" if u.public_roll

        # dashboard
        puts "  dashbaord : #{u.dashboard_entries.count} entries"

        #cohorts
        puts "  cohorts   : #{u.cohorts} (#{u.cohorts.size})"

        #iOs
        puts "  GT iOS?   : #{!u.authentication_token.blank?}"
      end

      puts "===error checking=="
      puts " *FAIL* user has no downcase_nickname" if u.downcase_nickname.empty?
      puts " *FAIL* downcase_nickname does not match nickname: #{u.downcase_nickname} != #{u.nickname}" unless u.downcase_nickname == u.nickname.downcase
      if u.gt_enabled?
        # faux
        puts " *FAIL* User should not be FAUX if they're gt_enabled" if u.user_type == User::USER_TYPE[:faux]

        # special rolls
        puts " *FAIL* Missing public roll" unless u.public_roll
        puts " *FAIL* Not following their public roll" unless u.following_roll? u.public_roll
        puts " *FAIL* Missing upvoted roll" unless u.upvoted_roll
        puts " *FAIL* Not following their upvoted roll. FIX: Roll.find('#{u.upvoted_roll.id}').add_follower(User.find('#{u.id}'), false)" unless u.following_roll? u.upvoted_roll
        puts " *FAIL* upvoted_roll should only have 1 follower, has too many" if u.upvoted_roll.following_users.count > 1
        puts " *FAIL* Missing viewed roll" unless u.viewed_roll
        puts " *FAIL* Should not be following viewed roll" if u.following_roll? u.viewed_roll

        # other rolls info
        bad_rolls_count = u.roll_followings.select { |rf| rf.roll == nil } .size
        puts " *FAIL* Follows #{bad_rolls_count} non-existant rolls.  FIX: GT::UserDoctor.clean_roll_followings(User.find('#{u.id}'))" if bad_rolls_count > 0

        # cohorts
        puts " *FAIL* Should have at least one cohort.  FIX: User.find('#{u.id}').push(:cohorts => Settings::User.current_cohort)" if u.cohorts.size == 0
      elsif u.user_type == User::USER_TYPE[:faux]
        # public roll checking
        unless [Roll::TYPES[:special_public_upgraded], Roll::TYPES[:special_public]].include? u.public_roll.roll_type
          puts " *FAIL* Public roll should be :special_public (11) or :special_public_upgraded (16) but was #{u.public_roll.roll_type}"
        end
        puts " *FAIL* Public roll should have origin network" if u.public_roll.origin_network.empty?
      end

      puts "===done==="
    end

  end
end