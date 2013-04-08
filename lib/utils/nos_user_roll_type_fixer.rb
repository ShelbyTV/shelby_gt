# This was written to fix up all the old NOS users's roll properties so they are treated as user rolls in GT.
# Left checked in as demo code / in case it's useful in the near future.
#
# *Should only be used for DB repair/fixing*
#
# Usage:
#   Dev::NosUserRollTypeFixer.fix!
#
module Dev
  class NosUserRollTypeFixer

    def self.fix!
      total = 0
      fixed = 0
      while (true)
        begin
          usersToFix = User.where(:user_type => User::USER_TYPE[:real]).skip(64000)
          break if !usersToFix

          usersToFix.each do |u|
            total += 1
            if r = Roll.find(u.public_roll_id)
              r.roll_type = Roll::TYPES[:special_public_real_user]
              r.save
              fixed += 1
            end
            if total % 1000 == 0
              puts "Total: #{total}, Fixed: #{fixed}"
            end
          end
        rescue
          puts "Exception! Looping again..."
        end
      end
    end

  end
end
