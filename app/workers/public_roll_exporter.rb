class PublicRollExporter
  @queue = :personal_roll_export

  def self.perform(user_uid, email)
    if user = User.find(user_uid)
      GT::UserManager.export_public_roll(user, email)
    end
  end

end