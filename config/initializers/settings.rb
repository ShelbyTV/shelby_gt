#
# Using a simple gem to provide settings in the format Settings.Namespace.setting_name.
# The settings values themseleves are enumerated in the yml files (below)
#
# N.B. Do not use nesting within the yaml itself!  Current versions of parsers don't handle nesting
#      along with default blocks.
#
module Settings

  class ExternalAccounts < Settingslogic
    source "#{Rails.root}/config/settings/external_accounts.yml"
    namespace Rails.env
    load!
  end

  class Global < Settingslogic
    source "#{Rails.root}/config/settings/global.yml"
    namespace Rails.env
    load!
  end
  
  class Beanstalk < Settingslogic
    source "#{Rails.root}/config/settings/beanstalk.yml"
    namespace Rails.env
    load!
  end
  
  class User < Settingslogic
    source "#{Rails.root}/config/settings/user.yml"
    namespace Rails.env
    load!
  end
  
  class Roll < Settingslogic
    source "#{Rails.root}/config/settings/roll.yml"
    namespace Rails.env
    load!
  end
  
  class Frame < Settingslogic
    source "#{Rails.root}/config/settings/frame.yml"
    namespace Rails.env
    load!
  end
  
  class Video < Settingslogic
    source "#{Rails.root}/config/settings/video.yml"
    namespace Rails.env
    load!
  end
  
  class Conversation < Settingslogic
    source "#{Rails.root}/config/settings/conversation.yml"
    namespace Rails.env
    load!
  end
  
  class DashboardEntry < Settingslogic
    source "#{Rails.root}/config/settings/dashboard_entry.yml"
    namespace Rails.env
    load!
  end
  
  class Embedly < Settingslogic
    source "#{Rails.root}/config/settings/embedly.yml"
    namespace Rails.env
    load!
  end
  
end