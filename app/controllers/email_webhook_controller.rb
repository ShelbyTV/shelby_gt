class EmailWebhookController < ApplicationController
  def hook
    Rails.logger.info "Received an email with these params #{params}"
  end
end
