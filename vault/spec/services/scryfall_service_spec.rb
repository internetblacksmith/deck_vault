require 'rails_helper'

RSpec.describe ScryfallService do
  describe '.fetch_sets' do
    context 'when API call succeeds' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets')
          .to_return(
            status: 200,
            body: {
              data: [
                { code: 'lea', name: 'Limited Edition Alpha', released_at: '1993-08-05', card_count: 295, set_type: 'core', parent_set_code: nil },
                { code: 'leb', name: 'Limited Edition Beta', released_at: '1993-10-01', card_count: 302, set_type: 'core', parent_set_code: nil }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns array of formatted sets' do
        result = described_class.fetch_sets
        expect(result.length).to eq(2)
        expect(result.first[:code]).to eq('lea')
        expect(result.first[:name]).to eq('Limited Edition Alpha')
      end

      it 'includes all set fields' do
        result = described_class.fetch_sets.first
        expect(result).to have_key(:code)
        expect(result).to have_key(:name)
        expect(result).to have_key(:released_at)
        expect(result).to have_key(:card_count)
        expect(result).to have_key(:set_type)
        expect(result).to have_key(:parent_set_code)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets')
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns empty array' do
        result = described_class.fetch_sets
        expect(result).to eq([])
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets')
          .to_raise(StandardError.new('Network error'))
      end

      it 'returns empty array' do
        result = described_class.fetch_sets
        expect(result).to eq([])
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Error fetching sets/)
        described_class.fetch_sets
      end
    end
  end

  describe '.fetch_cards_for_set' do
    context 'when fetching single page of cards' do
      before do
        stub_request(:get, 'https://api.scryfall.com/cards/search')
          .with(query: { q: 'set:tst unique:prints', page: 1 })
          .to_return(
            status: 200,
            body: {
              data: [
                { id: 'card-1', name: 'Card One', rarity: 'common', collector_number: '1', image_uris: { normal: 'https://example.com/1.jpg' } },
                { id: 'card-2', name: 'Card Two', rarity: 'rare', collector_number: '2', image_uris: { normal: 'https://example.com/2.jpg' } }
              ],
              has_more: false
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns array of formatted cards' do
        result = described_class.fetch_cards_for_set('tst')
        expect(result.length).to eq(2)
        expect(result.first[:id]).to eq('card-1')
        expect(result.first[:name]).to eq('Card One')
      end
    end

    context 'when fetching paginated results' do
      before do
        stub_request(:get, 'https://api.scryfall.com/cards/search')
          .with(query: { q: 'set:tst unique:prints', page: 1 })
          .to_return(
            status: 200,
            body: { data: [ { id: 'card-1', name: 'Card One', image_uris: {} } ], has_more: true }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, 'https://api.scryfall.com/cards/search')
          .with(query: { q: 'set:tst unique:prints', page: 2 })
          .to_return(
            status: 200,
            body: { data: [ { id: 'card-2', name: 'Card Two', image_uris: {} } ], has_more: false }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Skip sleep in tests
        allow(described_class).to receive(:sleep)
      end

      it 'fetches all pages' do
        result = described_class.fetch_cards_for_set('tst')
        expect(result.length).to eq(2)
      end

      it 'applies rate limiting between pages' do
        expect(described_class).to receive(:sleep).with(0.1).once
        described_class.fetch_cards_for_set('tst')
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, 'https://api.scryfall.com/cards/search')
          .to_return(status: 404, body: { object: 'error', details: 'No cards found' }.to_json)
      end

      it 'returns empty array' do
        result = described_class.fetch_cards_for_set('invalid')
        expect(result).to eq([])
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, 'https://api.scryfall.com/cards/search')
          .to_raise(StandardError.new('Timeout'))
      end

      it 'returns empty array' do
        result = described_class.fetch_cards_for_set('tst')
        expect(result).to eq([])
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Error fetching cards/)
        described_class.fetch_cards_for_set('tst')
      end
    end
  end

  describe '.format_set' do
    let(:set_data) do
      {
        'code' => 'lea',
        'name' => 'Limited Edition Alpha',
        'released_at' => '1993-08-05',
        'card_count' => 295,
        'scryfall_uri' => 'https://scryfall.com/sets/lea',
        'set_type' => 'core',
        'parent_set_code' => nil
      }
    end

    it 'formats set data with symbol keys' do
      result = described_class.format_set(set_data)
      expect(result[:code]).to eq('lea')
      expect(result[:name]).to eq('Limited Edition Alpha')
      expect(result[:released_at]).to eq('1993-08-05')
      expect(result[:card_count]).to eq(295)
      expect(result[:set_type]).to eq('core')
      expect(result[:parent_set_code]).to be_nil
    end

    context 'with child set' do
      let(:child_set_data) do
        {
          'code' => 'pcel',
          'name' => 'Celebration Cards',
          'released_at' => '1993-08-05',
          'card_count' => 1,
          'set_type' => 'promo',
          'parent_set_code' => 'lea'
        }
      end

      it 'includes parent_set_code' do
        result = described_class.format_set(child_set_data)
        expect(result[:parent_set_code]).to eq('lea')
      end
    end
  end

  describe '.group_sets' do
    let(:sets) do
      [
        { code: 'lea', name: 'Alpha', parent_set_code: nil },
        { code: 'leb', name: 'Beta', parent_set_code: nil },
        { code: 'pcel', name: 'Alpha Promos', parent_set_code: 'lea' },
        { code: 'ptok', name: 'Alpha Tokens', parent_set_code: 'lea' }
      ]
    end

    it 'groups children under their parents' do
      result = described_class.group_sets(sets)
      expect(result.length).to eq(2) # Only parent sets

      alpha = result.find { |s| s[:code] == 'lea' }
      expect(alpha[:children].length).to eq(2)
      expect(alpha[:children].map { |c| c[:code] }).to contain_exactly('pcel', 'ptok')
    end

    it 'includes parent set data in result' do
      result = described_class.group_sets(sets)
      alpha = result.find { |s| s[:code] == 'lea' }
      expect(alpha[:name]).to eq('Alpha')
    end

    it 'returns empty children array for sets without children' do
      result = described_class.group_sets(sets)
      beta = result.find { |s| s[:code] == 'leb' }
      expect(beta[:children]).to eq([])
    end
  end

  describe '.fetch_set_details' do
    context 'when API call succeeds' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets/lea')
          .to_return(
            status: 200,
            body: { code: 'lea', name: 'Limited Edition Alpha', card_count: 295 }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns set details' do
        result = described_class.fetch_set_details('lea')
        expect(result['name']).to eq('Limited Edition Alpha')
        expect(result['card_count']).to eq(295)
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets/invalid')
          .to_return(status: 404, body: { object: 'error' }.to_json)
      end

      it 'returns empty hash' do
        result = described_class.fetch_set_details('invalid')
        expect(result).to eq({})
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets/lea')
          .to_raise(StandardError.new('Network error'))
      end

      it 'returns empty hash' do
        result = described_class.fetch_set_details('lea')
        expect(result).to eq({})
      end
    end
  end

  describe '.fetch_child_sets' do
    before do
      stub_request(:get, 'https://api.scryfall.com/sets')
        .to_return(
          status: 200,
          body: {
            data: [
              { code: 'lea', name: 'Alpha', parent_set_code: nil },
              { code: 'pcel', name: 'Alpha Promos', parent_set_code: 'lea' },
              { code: 'tlae', name: 'Alpha Tokens', parent_set_code: 'lea' },
              { code: 'leb', name: 'Beta', parent_set_code: nil }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns codes of child sets' do
      result = described_class.fetch_child_sets('lea')
      expect(result).to contain_exactly('pcel', 'tlae')
    end

    it 'returns empty array for set without children' do
      result = described_class.fetch_child_sets('leb')
      expect(result).to eq([])
    end

    context 'when network error occurs' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets')
          .to_raise(StandardError.new('Error'))
      end

      it 'returns empty array' do
        result = described_class.fetch_child_sets('lea')
        expect(result).to eq([])
      end
    end
  end

  describe '.download_set' do
    let(:set_details) do
      { 'code' => 'tst', 'name' => 'Test Set', 'card_count' => 1, 'released_at' => '2024-01-01', 'set_type' => 'expansion', 'parent_set_code' => nil }
    end

    let(:card_data) do
      [ { id: 'card-1', name: 'Test Card', image_uris: '{}', rarity: 'common', collector_number: '1' } ]
    end

    before do
      stub_request(:get, 'https://api.scryfall.com/sets/tst')
        .to_return(status: 200, body: set_details.to_json, headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, 'https://api.scryfall.com/cards/search')
        .with(query: { q: 'set:tst unique:prints', page: 1 })
        .to_return(status: 200, body: { data: [ { id: 'card-1', name: 'Test Card', image_uris: {} } ], has_more: false }.to_json, headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, 'https://api.scryfall.com/sets')
        .to_return(status: 200, body: { data: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

      allow(DownloadCardImagesJob).to receive(:perform_later)
    end

    it 'creates card set in database' do
      expect {
        described_class.download_set('tst')
      }.to change(CardSet, :count).by(1)

      card_set = CardSet.find_by(code: 'tst')
      expect(card_set.name).to eq('Test Set')
    end

    it 'creates cards in database' do
      expect {
        described_class.download_set('tst')
      }.to change(Card, :count).by(1)
    end

    it 'queues image download jobs' do
      expect(DownloadCardImagesJob).to receive(:perform_later).with('card-1')
      described_class.download_set('tst')
    end

    it 'returns the card set' do
      result = described_class.download_set('tst')
      expect(result).to be_a(CardSet)
      expect(result.code).to eq('tst')
    end

    context 'with include_children: true' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets')
          .to_return(
            status: 200,
            body: { data: [ { code: 'tst', name: 'Test Set', parent_set_code: nil }, { code: 'ptst', name: 'Test Promos', parent_set_code: 'tst' } ] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, 'https://api.scryfall.com/sets/ptst')
          .to_return(status: 200, body: { 'code' => 'ptst', 'name' => 'Test Promos', 'card_count' => 1, 'parent_set_code' => 'tst' }.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:get, 'https://api.scryfall.com/cards/search')
          .with(query: { q: 'set:ptst unique:prints', page: 1 })
          .to_return(status: 200, body: { data: [ { id: 'promo-1', name: 'Promo Card', image_uris: {} } ], has_more: false }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'downloads child sets' do
        expect {
          described_class.download_set('tst', include_children: true)
        }.to change(CardSet, :count).by(2)
      end
    end

    context 'when set details fetch fails' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets/bad')
          .to_return(status: 404, body: { object: 'error' }.to_json)

        stub_request(:get, 'https://api.scryfall.com/cards/search')
          .with(query: { q: 'set:bad unique:prints', page: 1 })
          .to_return(status: 200, body: { data: [], has_more: false }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'still creates set with nil values for missing data' do
        result = described_class.download_single_set('bad')
        expect(result).to be_a(CardSet)
        expect(result.code).to eq('bad')
        expect(result.name).to be_nil # No set details available
      end
    end

    context 'when card fetch returns empty results' do
      before do
        stub_request(:get, 'https://api.scryfall.com/sets/empty')
          .to_return(status: 200, body: { 'code' => 'empty', 'name' => 'Empty Set', 'card_count' => 0 }.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:get, 'https://api.scryfall.com/cards/search')
          .with(query: { q: 'set:empty unique:prints', page: 1 })
          .to_return(status: 404, body: { object: 'error', details: 'No cards found' }.to_json)

        stub_request(:get, 'https://api.scryfall.com/sets')
          .to_return(status: 200, body: { data: [] }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'creates set with no cards' do
        result = described_class.download_single_set('empty')
        expect(result).to be_a(CardSet)
        expect(result.cards.count).to eq(0)
      end
    end
  end

  describe '.download_card_image' do
    context 'when download fails' do
      let(:card_data) do
        { id: 'test-123', name: 'Test Card', image_uris: { 'normal' => 'https://example.com/card.jpg' } }
      end

      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'returns nil on HTTP error' do
        allow(HTTParty).to receive(:get).and_return(double(success?: false))
        result = described_class.download_card_image(card_data)
        expect(result).to be_nil
      end

      it 'returns nil on network timeout' do
        allow(HTTParty).to receive(:get).and_raise(Net::ReadTimeout)
        result = described_class.download_card_image(card_data)
        expect(result).to be_nil
      end

      it 'logs error on failure' do
        allow(HTTParty).to receive(:get).and_raise(StandardError.new('Connection refused'))
        expect(Rails.logger).to receive(:error).with(/Error downloading card image/)
        described_class.download_card_image(card_data)
      end
    end
  end

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
