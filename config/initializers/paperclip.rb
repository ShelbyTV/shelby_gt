#
# User Avatar via paperclip
#

# Store avatar on S3
Paperclip::Attachment.default_options[:storage] = :s3
Paperclip::Attachment.default_options[:s3_credentials] = {
    :access_key_id => Settings::Paperclip.access_key_id, 
    :secret_access_key => Settings::Paperclip.secret_access_key
    }
Paperclip::Attachment.default_options[:bucket] = Settings::Paperclip.bucket
Paperclip::Attachment.default_options[:path] = "/:style/:id/:filename"

# The paperclip plugin provides lots of view helpers to construct the avatar URL
# We will not be passing all of these over the API
#
# Using the format of :path above, here's how you contruct an avatar URL:
#   http://s3.amazonaws.com/shelby-gt-user-avatars/<style>/<user.id>/<user.avatar_file_name>
# Where <style> is one of the pre-defined sizes is user.rb, currently:
# :styles => { :sq192x192 => "192x192#", :sq48x48 => "48x48#" }
#
# Example of a large thumbnail URL:
#   http://s3.amazonaws.com/dev-shelby-gt-user-avatars/sq192x192/4fa141009fb5ba2b2b000002/dan_ani_with_cow.gif?2012
#
# You can also get at the originally uploaded image (with original aspect ratio) using the "original" style:
#   http://s3.amazonaws.com/dev-shelby-gt-user-avatars/original/4fa141009fb5ba2b2b000002/dan_ani_with_cow.gif?2012
#
# (FYI: Not sure why paperclip appends the year of the upload to the URL, assuming some sort of cache busting, but it's not necessary)



# Stop crapping all over my console
Paperclip.options[:logger] = Rails.logger