#
# User Avatar via paperclip
#

# Store avatar on S3
Paperclip::Attachment.default_options[:storage] = :s3
Paperclip::Attachment.default_options[:s3_credentials] = {
    :access_key_id => Settings::Paperclip.access_key_id, 
    :secret_access_key => Settings::Paperclip.secret_access_key
    }

# Stop crapping all over my console
Paperclip.options[:logger] = Rails.logger