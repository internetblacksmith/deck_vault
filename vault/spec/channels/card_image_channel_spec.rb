require 'rails_helper'

RSpec.describe CardImageChannel, type: :channel do
  before do
    stub_connection
  end

  describe '#subscribed' do
    it 'successfully subscribes to card image stream' do
      subscribe(card_id: 'test-card-123')

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from('card_image:test-card-123')
    end

    it 'streams from correct channel based on card_id' do
      subscribe(card_id: 'abc-def-456')

      expect(subscription).to have_stream_from('card_image:abc-def-456')
    end
  end

  describe '#unsubscribed' do
    it 'unsubscribes without error' do
      subscribe(card_id: 'test-card-123')

      expect { subscription.unsubscribe_from_channel }.not_to raise_error
    end
  end
end
