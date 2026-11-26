# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentNotifications::ConversationNotificationsMailer do
  let(:class_instance) { described_class.new }
  let!(:account) { create(:account) }
  let(:agent) { create(:user, email: 'agent1@example.com', account: account) }
  let(:conversation) { create(:conversation, assignee: agent, account: account) }

  def conversation_label(conversation)
    name = conversation.contact&.name.presence
    name ? "#{name} (##{conversation.display_id})" : "##{conversation.display_id}"
  end

  before do
    allow(described_class).to receive(:new).and_return(class_instance)
    allow(class_instance).to receive(:smtp_config_set_or_development?).and_return(true)
  end

  describe 'conversation_creation' do
    let(:mail) { described_class.with(account: account).conversation_creation(conversation, agent, nil).deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq("Nova conversa #{conversation_label(conversation)} em #{conversation.inbox&.sanitized_name}")
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([agent.email])
    end
  end

  describe 'conversation_assignment' do
    let(:mail) { described_class.with(account: account).conversation_assignment(conversation, agent, nil).deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq("#{agent.available_name}, uma nova conversa foi atribuída a você: #{conversation_label(conversation)}")
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([agent.email])
    end
  end

  describe 'conversation_mention' do
    let(:contact) { create(:contact, name: nil, account: account) }
    let(:another_agent) { create(:user, email: 'agent2@example.com', account: account) }
    let(:message) { create(:message, conversation: conversation, account: account, sender: another_agent) }
    let(:mail) { described_class.with(account: account).conversation_mention(conversation, agent, message).deliver_now }
    let(:contact_inbox) { create(:contact_inbox, account: account, inbox: conversation.inbox) }

    before do
      create(:message, conversation: conversation, account: account, sender: contact)
      create(:message, conversation: conversation, account: account, sender: contact)
      create(:message, conversation: conversation, account: account, sender: contact)
    end

    it 'renders the subject' do
      expect(mail.subject).to eq("#{agent.available_name}, você foi mencionado na conversa #{conversation_label(conversation)}")
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([agent.email])
    end

    it 'renders the senders name' do
      expect(mail.body.encoded).to match("<strong>#{another_agent.display_name}</strong> mencionou você em uma conversa:")
    end

    it 'renders Customer if contacts name not available in the conversation' do
      expect(contact.name).to be_nil
      expect(conversation.recent_messages).not_to be_empty
      expect(mail.body.encoded).to match('Incoming Message')
    end
  end

  describe 'assigned_conversation_new_message' do
    let(:message) { create(:message, conversation: conversation, account: account) }
    let(:mail) { described_class.with(account: account).assigned_conversation_new_message(conversation, agent, message).deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq("#{agent.available_name}, nova mensagem na sua conversa #{conversation_label(message.conversation)}")
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([agent.email])
    end

    it 'will not send email if agent is online' do
      OnlineStatusTracker.update_presence(conversation.account.id, 'User', agent.id)
      expect(mail).to be_nil
    end
  end

  describe 'participating_conversation_new_message' do
    let(:message) { create(:message, conversation: conversation, account: account) }
    let(:mail) { described_class.with(account: account).participating_conversation_new_message(conversation, agent, message).deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq("#{agent.available_name}, nova mensagem na conversa #{conversation_label(message.conversation)}")
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([agent.email])
    end

    it 'will not send email if agent is online' do
      OnlineStatusTracker.update_presence(conversation.account.id, 'User', agent.id)
      expect(mail).to be_nil
    end
  end
end
