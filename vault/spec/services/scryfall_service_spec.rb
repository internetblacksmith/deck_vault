require 'rails_helper'

RSpec.describe ScryfallService do
  describe '.extract_image_uris' do
    context 'with normal card (image_uris at top level)' do
      let(:card_data) do
        {
          'image_uris' => {
            'normal' => 'https://example.com/front.jpg',
            'small' => 'https://example.com/front_small.jpg'
          }
        }
      end

      it 'returns front image URIs as first element' do
        front_uris, _back_uris = described_class.extract_image_uris(card_data)
        expect(front_uris['normal']).to eq('https://example.com/front.jpg')
      end

      it 'returns nil for back image URIs' do
        _front_uris, back_uris = described_class.extract_image_uris(card_data)
        expect(back_uris).to be_nil
      end
    end

    context 'with double-faced card (image_uris in card_faces)' do
      let(:card_data) do
        {
          'card_faces' => [
            {
              'name' => 'Front Face',
              'image_uris' => {
                'normal' => 'https://example.com/front.jpg',
                'small' => 'https://example.com/front_small.jpg'
              }
            },
            {
              'name' => 'Back Face',
              'image_uris' => {
                'normal' => 'https://example.com/back.jpg',
                'small' => 'https://example.com/back_small.jpg'
              }
            }
          ]
        }
      end

      it 'returns front image URIs from first card_face' do
        front_uris, _back_uris = described_class.extract_image_uris(card_data)
        expect(front_uris['normal']).to eq('https://example.com/front.jpg')
      end

      it 'returns back image URIs from second card_face' do
        _front_uris, back_uris = described_class.extract_image_uris(card_data)
        expect(back_uris['normal']).to eq('https://example.com/back.jpg')
      end
    end

    context 'with card_faces but only one face' do
      let(:card_data) do
        {
          'card_faces' => [
            {
              'name' => 'Only Face',
              'image_uris' => {
                'normal' => 'https://example.com/front.jpg'
              }
            }
          ]
        }
      end

      it 'returns front image URIs' do
        front_uris, _back_uris = described_class.extract_image_uris(card_data)
        expect(front_uris['normal']).to eq('https://example.com/front.jpg')
      end

      it 'returns nil for back image URIs' do
        _front_uris, back_uris = described_class.extract_image_uris(card_data)
        expect(back_uris).to be_nil
      end
    end

    context 'with no image data' do
      let(:card_data) { {} }

      it 'returns nil for both front and back' do
        front_uris, back_uris = described_class.extract_image_uris(card_data)
        expect(front_uris).to be_nil
        expect(back_uris).to be_nil
      end
    end
  end

  describe '.format_card' do
    context 'with normal card' do
      let(:card_data) do
        {
          'id' => 'abc-123',
          'name' => 'Lightning Bolt',
          'mana_cost' => '{R}',
          'type_line' => 'Instant',
          'oracle_text' => 'Deal 3 damage to any target.',
          'rarity' => 'common',
          'collector_number' => '1',
          'foil' => true,
          'nonfoil' => true,
          'image_uris' => {
            'normal' => 'https://example.com/bolt.jpg'
          }
        }
      end

      it 'formats basic card data correctly' do
        result = described_class.format_card(card_data)
        expect(result[:id]).to eq('abc-123')
        expect(result[:name]).to eq('Lightning Bolt')
        expect(result[:mana_cost]).to eq('{R}')
        expect(result[:rarity]).to eq('common')
      end

      it 'includes foil and nonfoil flags' do
        result = described_class.format_card(card_data)
        expect(result[:foil]).to be true
        expect(result[:nonfoil]).to be true
      end

      it 'includes image_uris as JSON' do
        result = described_class.format_card(card_data)
        parsed = JSON.parse(result[:image_uris])
        expect(parsed['normal']).to eq('https://example.com/bolt.jpg')
      end

      it 'sets back_image_uris to nil for non-DFC' do
        result = described_class.format_card(card_data)
        expect(result[:back_image_uris]).to be_nil
      end
    end

    context 'with double-faced card' do
      let(:card_data) do
        {
          'id' => 'dfc-456',
          'name' => 'Delver of Secrets // Insectile Aberration',
          'mana_cost' => '{U}',
          'type_line' => 'Creature — Human Wizard',
          'oracle_text' => 'Transform text...',
          'rarity' => 'common',
          'collector_number' => '51',
          'foil' => true,
          'nonfoil' => true,
          'card_faces' => [
            {
              'name' => 'Delver of Secrets',
              'image_uris' => { 'normal' => 'https://example.com/delver_front.jpg' }
            },
            {
              'name' => 'Insectile Aberration',
              'image_uris' => { 'normal' => 'https://example.com/delver_back.jpg' }
            }
          ]
        }
      end

      it 'includes front image_uris from first face' do
        result = described_class.format_card(card_data)
        parsed = JSON.parse(result[:image_uris])
        expect(parsed['normal']).to eq('https://example.com/delver_front.jpg')
      end

      it 'includes back_image_uris from second face' do
        result = described_class.format_card(card_data)
        parsed = JSON.parse(result[:back_image_uris])
        expect(parsed['normal']).to eq('https://example.com/delver_back.jpg')
      end
    end

    context 'with foil-only card' do
      let(:card_data) do
        {
          'id' => 'foil-789',
          'name' => 'Foil Promo',
          'foil' => true,
          'nonfoil' => false,
          'image_uris' => { 'normal' => 'https://example.com/promo.jpg' }
        }
      end

      it 'correctly captures foil-only status' do
        result = described_class.format_card(card_data)
        expect(result[:foil]).to be true
        expect(result[:nonfoil]).to be false
      end
    end

    context 'with nonfoil-only card' do
      let(:card_data) do
        {
          'id' => 'nonfoil-101',
          'name' => 'Basic Land',
          'foil' => false,
          'nonfoil' => true,
          'image_uris' => { 'normal' => 'https://example.com/land.jpg' }
        }
      end

      it 'correctly captures nonfoil-only status' do
        result = described_class.format_card(card_data)
        expect(result[:foil]).to be false
        expect(result[:nonfoil]).to be true
      end
    end

    context 'with missing foil/nonfoil fields' do
      let(:card_data) do
        {
          'id' => 'missing-fields',
          'name' => 'Unknown Card',
          'image_uris' => { 'normal' => 'https://example.com/card.jpg' }
        }
      end

      it 'defaults foil to false' do
        result = described_class.format_card(card_data)
        expect(result[:foil]).to be false
      end

      it 'defaults nonfoil to true' do
        result = described_class.format_card(card_data)
        expect(result[:nonfoil]).to be true
      end
    end
  end

  describe '.download_card_image' do
    let(:card_data) do
      {
        id: 'test-123',
        name: 'Test Card',
        image_uris: { 'normal' => 'https://example.com/card.jpg' }
      }
    end

    before do
      allow(HTTParty).to receive(:get).and_return(
        double(success?: true, body: 'fake image data')
      )
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:open).and_yield(double(write: true))
      allow(FileUtils).to receive(:mkdir_p)
    end

    it 'returns path with suffix when provided' do
      result = described_class.download_card_image(card_data, suffix: '_back')
      expect(result).to eq('card_images/test-123_back.jpg')
    end

    it 'returns path without suffix by default' do
      result = described_class.download_card_image(card_data)
      expect(result).to eq('card_images/test-123.jpg')
    end

    it 'returns nil when card_data is nil' do
      result = described_class.download_card_image(nil)
      expect(result).to be_nil
    end

    it 'returns nil when image_uris is missing' do
      result = described_class.download_card_image({ id: 'test', name: 'Test' })
      expect(result).to be_nil
    end

    context 'when image already exists' do
      before do
        allow(File).to receive(:exist?).and_return(true)
      end

      it 'returns existing path without downloading' do
        expect(HTTParty).not_to receive(:get)
        result = described_class.download_card_image(card_data)
        expect(result).to eq('card_images/test-123.jpg')
      end
    end
  end

  describe '.refresh_set' do
    let(:card_set) { create(:card_set, code: 'tst', name: 'Test Set') }

    before do
      allow(described_class).to receive(:fetch_set_details).and_return({ 'card_count' => 2, 'name' => 'Test Set' })
    end

    context 'when cards exist with missing images' do
      let!(:card_with_image) do
        create(:card, card_set: card_set, name: 'Card With Image', image_path: 'card_images/abc.jpg')
      end
      let!(:card_without_image) do
        create(:card, card_set: card_set, name: 'Card Without Image', image_path: nil)
      end

      before do
        # Mock fetch_cards_for_set to return data for existing cards
        allow(described_class).to receive(:fetch_cards_for_set).and_return([
          { id: card_with_image.id, name: 'Card With Image', image_uris: '{}' },
          { id: card_without_image.id, name: 'Card Without Image', image_uris: '{}' }
        ])
      end

      it 'queues image download only for cards missing images' do
        expect(DownloadCardImagesJob).to receive(:perform_later).with(card_without_image.id).once
        expect(DownloadCardImagesJob).not_to receive(:perform_later).with(card_with_image.id)

        result = described_class.refresh_set(card_set)
        expect(result[:images_queued]).to eq(1)
      end

      it 'returns count of images queued' do
        allow(DownloadCardImagesJob).to receive(:perform_later)

        result = described_class.refresh_set(card_set)
        expect(result[:images_queued]).to eq(1)
        expect(result[:updated]).to eq(2)
        expect(result[:added]).to eq(0)
      end
    end

    context 'when new cards are added' do
      before do
        allow(described_class).to receive(:fetch_cards_for_set).and_return([
          { id: 'new-card-id', name: 'New Card', image_uris: '{}' }
        ])
      end

      it 'queues image download for new cards' do
        expect(DownloadCardImagesJob).to receive(:perform_later).once

        result = described_class.refresh_set(card_set)
        expect(result[:added]).to eq(1)
        expect(result[:images_queued]).to eq(1)
      end
    end

    context 'when all cards already have images' do
      let!(:card_with_image) do
        create(:card, card_set: card_set, name: 'Complete Card', image_path: 'card_images/complete.jpg')
      end

      before do
        allow(described_class).to receive(:fetch_cards_for_set).and_return([
          { id: card_with_image.id, name: 'Complete Card', image_uris: '{}' }
        ])
      end

      it 'does not queue any image downloads' do
        expect(DownloadCardImagesJob).not_to receive(:perform_later)

        result = described_class.refresh_set(card_set)
        expect(result[:images_queued]).to eq(0)
      end
    end

    context 'when Scryfall API fails' do
      before do
        allow(described_class).to receive(:fetch_cards_for_set).and_return([])
      end

      it 'returns error with images_queued as 0' do
        result = described_class.refresh_set(card_set)
        expect(result[:error]).to be_present
        expect(result[:images_queued]).to eq(0)
      end
    end
  end
end
