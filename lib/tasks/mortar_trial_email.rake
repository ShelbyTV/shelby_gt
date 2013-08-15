namespace :gt_email do

  desc 'Send Mortar Trial Email'
  task :send_mortar_trial_email => :environment do
    require 'mortar_harvester'

    trial_participant_usernames = Settings::Testing.shelby_test_participants_usernames
    print "Processing #{trial_participant_usernames.length} users"

    # some hackery to set up an equal number of users who get the video reason and don't get the video reason,
    # while making those two groups of people different every time
    num_users_getting_reason = trial_participant_usernames.length / 2
    include_reason_bools = (([true] * num_users_getting_reason) + ([false] * (trial_participant_usernames.length - num_users_getting_reason))).shuffle

    trial_participants = User.where(:nickname => { :$in => trial_participant_usernames })
    emails_sent = 0

    trial_participants.find_each.each_with_index do |u, i|

      if u.primary_email && u.primary_email != ""
        if recs = GT::MortarHarvester.get_recs_for_user(u)
          if mail = MortarMailer.mortar_recommendation_trial(u, recs, include_reason_bools[i]).deliver
            print "\nSending emails:\n" if emails_sent == 0
            print '.'
            emails_sent += 1
          end
        end
      end

    end

    print "\nSent #{emails_sent} emails\n"

  end

end