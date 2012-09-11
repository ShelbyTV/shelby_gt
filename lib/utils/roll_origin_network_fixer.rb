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
      rollsToFix = Roll.where(:roll_type => Roll::TYPES[:special_public], :origin_network => nil).limit(10)
      rollsToFix.each do |r|
        puts r
      end if rollsToFix
    end

  end
end
