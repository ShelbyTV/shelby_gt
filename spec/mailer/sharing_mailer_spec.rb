require 'spec_helper'
 
describe SharingMailer do
  describe 'share frame' do
    @from_user = Factory.create(:user, :primary_email => 'lucas@email.com') }
    let(:mail) { Notifier.instructions(user) }
 
    #ensure that the subject is correct
    it 'renders the subject' do
      mail.subject.should == 'Instructions'
    end
 
    #ensure that the receiver is correct
    it 'renders the receiver email' do
      mail.to.should == [user.email]
    end
 
    #ensure that the sender is correct
    it 'renders the sender email' do
      mail.from.should == ['noreply@empresa.com']
    end
 
    #ensure that the @name variable appears in the email body
    it 'assigns @name' do
      mail.body.encoded.should match(user.name)
    end
 
    #ensure that the @confirmation_url variable appears in the email body
    it 'assigns @confirmation_url' do
      mail.body.encoded.should match("http://aplication_url/#{user.id}/confirmation")
    end
  end
end