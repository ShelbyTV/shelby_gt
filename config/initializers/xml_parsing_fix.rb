# https://groups.google.com/forum/#!topic/rubyonrails-security/61bkgvnSGTQ/discussion
# Patched until we can upgrade to Rails 3.2.11 which fixes the XML parsing vulnerability
ActionDispatch::ParamsParser::DEFAULT_PARSERS.delete(Mime::XML) 