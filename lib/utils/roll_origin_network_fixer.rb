# Initially, the origin_network property of a Roll didn't exist.
# This was written to fix up all the old Roll origin network properties for faux user person rolls. 
# Left checked in as demo code / in case it's useful in the near future.
#
# *Should only be used for DB repair/fixing* 
#
# Usage:
#   Dev::RollOriginNetworkFixer.fix!
#
module Dev
  class RollOriginNetworkFixer
    
    def self.fix!
      total = 0
      fixed = 0
      rollsToFix = Roll.where(:roll_type => Roll::TYPES[:special_public], :origin_network => nil).limit(100)
      rollsToFix.each do |r|
        total += 1
        if u = User.find(r.creator_id)
          if u.authentications.count == 1
            #r.origin_network = u.authentications.first.provider
            puts "r.origin_network = #{u.authentications.first.provider}"
            #r.save
            fixed += 1
          end
        end
        if total % 10 == 0
          puts "Total: #{total}, Fixed: #{fixed}\n"
        end
      end if rollsToFix
    end

  end
end
