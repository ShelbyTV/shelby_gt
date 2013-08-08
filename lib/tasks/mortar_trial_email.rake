namespace :gt_email do

  desc 'Send Mortar Trial Email'
  task :send_mortar_trial_email => :environment do

    trial_participant_nicknames = ['iceberg901']
    trial_participants = User.where(:nickname => { :$in => trial_participant_nicknames })
    emails_sent = 0

    puts 'Starting Processing'

    trial_participants.find_each do |u|

      if u.primary_email && u.primary_email != ""
        if recs = GT::MortarHarvester.get_recs_for_user(u)
          if mail = MortarMailer.mortar_recommendation_trial(u, recs).deliver
            puts "\nSending emails:\n" if emails_sent == 0
            print '.'
            emails_sent += 1
          end
        end
      end

    end

    print "\nSent #{emails_sent} emails\n"

  end

end