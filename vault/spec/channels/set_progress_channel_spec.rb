require 'rails_helper'

RSpec.describe SetProgressChannel, type: :channel do
  before do
    stub_connection
  end

  describe '#subscribed' do
    it 'successfully subscribes to set progress stream' do
      subscribe(card_set_id: 'test-set-123')

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from('set_progress:test-set-123')
    end

    it 'streams from correct channel based on card_set_id' do
      subscribe(card_set_id: 'abc-def-456')

      expect(subscription).to have_stream_from('set_progress:abc-def-456')
    end

    it 'handles numeric card_set_id' do
      subscribe(card_set_id: 42)

      expect(subscription).to have_stream_from('set_progress:42')
    end
  end

  describe '#unsubscribed' do
    it 'unsubscribes without error' do
      subscribe(card_set_id: 'test-set-123')

      expect { subscription.unsubscribe_from_channel }.not_to raise_error
    end
  end
end
