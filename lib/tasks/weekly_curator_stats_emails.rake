namespace :stats_emails do

  desc 'Send Weekly Curator Stats Email'
  task :send_weekly_curator_stats_emails => :environment do

    active_curator_ids = ['adventurous','arthur','blgevanter','bsoist','chris','christopherritter','enelson1','francisco','gulp','henry','iceberg901','ilyasny','imnotjk','kehrseite','lavvocato','madeinnydemo','matyus','migupatricio','nicholas','reece','shawn.crosby','spinosa','sxsw','the_adventurous','vondoom','yusufroso']
    active_curators = User.where(:nickname => { :$in => active_curator_ids })
    emails_sent = 0

    print 'Looking up active curators'

    active_curators.find_each do |u|

      if u.primary_email && u.primary_email != "" && u.preferences.email_updates
        if mail = StatsMailer.weekly_curator_stats(u).deliver
          print "\nSending emails:\n" if emails_sent == 0
          print '.'
          emails_sent += 1
        end
      end

    end

    print "\nSent #{emails_sent} emails\n"

  end

end