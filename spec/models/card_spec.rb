require 'rails_helper'

RSpec.describe Card, type: :model do
  # Associations
  describe 'associations' do
    it { is_expected.to belong_to(:card_set) }
    it { is_expected.to have_one(:collection_card).dependent(:destroy) }
  end

  # Validations
  describe 'validations' do
    subject { build(:card) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:scryfall_id) }
    it { is_expected.to validate_uniqueness_of(:scryfall_id).case_insensitive }

    context 'when name is missing' do
      before { subject.name = nil }
      it { is_expected.not_to be_valid }
    end

    context 'when scryfall_id is missing' do
      before { subject.scryfall_id = nil }
      it { is_expected.not_to be_valid }
    end

    context 'when scryfall_id already exists' do
      before do
        create(:card, scryfall_id: '12345678-1234-1234-1234-123456789012')
        subject.scryfall_id = '12345678-1234-1234-1234-123456789012'
      end

      it { is_expected.not_to be_valid }
    end

    context 'when all required fields are present' do
      subject { build(:card, name: 'Lightning Bolt', scryfall_id: '12345678-1234-1234-1234-123456789012') }
      it { is_expected.to be_valid }
    end

    context 'when type_line is empty' do
      subject { build(:card, type_line: '') }
      it { is_expected.to be_valid }
    end

    context 'when oracle_text is empty' do
      subject { build(:card, oracle_text: '') }
      it { is_expected.to be_valid }
    end
  end

  # Methods
  describe '#to_image_hash' do
    context 'when image_uris contains valid JSON' do
      subject { create(:card, image_uris: { normal: 'https://example.com/normal.jpg', small: 'https://example.com/small.jpg' }.to_json) }

      it 'returns hash with scryfall_id, name, and image_uris' do
        result = subject.to_image_hash
        expect(result[:id]).to eq(subject.scryfall_id)
        expect(result[:name]).to eq(subject.name)
        expect(result[:image_uris]).to be_a(Hash)
      end

      it 'parses image_uris JSON correctly' do
        result = subject.to_image_hash
        expect(result[:image_uris]['normal']).to eq('https://example.com/normal.jpg')
        expect(result[:image_uris]['small']).to eq('https://example.com/small.jpg')
      end
    end

    context 'when image_uris is empty JSON object' do
      subject { create(:card, image_uris: '{}') }

      it 'returns empty hash for image_uris' do
        result = subject.to_image_hash
        expect(result[:image_uris]).to eq({})
      end
    end

    context 'when image_uris is nil' do
      subject { create(:card, image_uris: nil) }

      it 'returns empty hash for image_uris' do
        result = subject.to_image_hash
        expect(result[:image_uris]).to eq({})
      end
    end

    context 'when image_uris has multiple formats' do
      subject do
        create(:card, image_uris: {
          small: 'https://example.com/small.jpg',
          normal: 'https://example.com/normal.jpg',
          large: 'https://example.com/large.jpg',
          png: 'https://example.com/png.png',
          art_crop: 'https://example.com/art.jpg',
          border_crop: 'https://example.com/border.jpg'
        }.to_json)
      end

      it 'preserves all image formats' do
        result = subject.to_image_hash
        expect(result[:image_uris].keys).to match_array([ 'small', 'normal', 'large', 'png', 'art_crop', 'border_crop' ])
      end
    end
  end

  # Touch behavior
  describe 'touch behavior' do
    subject { create(:card) }

    it 'has touch: true on belongs_to association' do
      original_updated_at = subject.card_set.updated_at
      sleep 0.1
      subject.update(rarity: 'rare')
      subject.card_set.reload
      expect(subject.card_set.updated_at).to be >= original_updated_at
    end
  end

  # Timestamps
  describe 'timestamps' do
    subject { create(:card) }

    it { is_expected.to have_attributes(created_at: be_a(Time), updated_at: be_a(Time)) }

    it 'updates updated_at when modified' do
      original_updated_at = subject.updated_at
      sleep 0.1
      subject.update(name: 'Updated Card Name')
      expect(subject.updated_at).to be >= original_updated_at
    end
  end

  # Attributes
  describe 'attributes' do
    subject { create(:card) }

    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:scryfall_id) }
    it { is_expected.to respond_to(:card_set_id) }
    it { is_expected.to respond_to(:collector_number) }
    it { is_expected.to respond_to(:type_line) }
    it { is_expected.to respond_to(:mana_cost) }
    it { is_expected.to respond_to(:rarity) }
    it { is_expected.to respond_to(:oracle_text) }
    it { is_expected.to respond_to(:image_uris) }
    it { is_expected.to respond_to(:image_path) }
  end

  # Factory
  describe 'factory' do
    subject { build(:card) }

    it 'builds a valid card' do
      expect(subject).to be_valid
    end

    it 'has required attributes' do
      expect(subject.name).to be_present
      expect(subject.scryfall_id).to be_present
    end

    it 'belongs to a card_set' do
      expect(subject.card_set).to be_a(CardSet)
    end

    context 'with :with_image trait' do
      subject { build(:card, :with_image) }

      it 'has an image_path' do
        expect(subject.image_path).to be_present
      end
    end

    context 'with :without_image_uris trait' do
      subject { build(:card, :without_image_uris) }

      it 'has empty image_uris' do
        expect(subject.image_uris).to eq('{}')
      end
    end

    context 'with :with_collection_card trait' do
      subject { create(:card, :with_collection_card) }

      it 'creates associated collection_card' do
        expect(subject.collection_card).to be_a(CollectionCard)
      end
    end

    it 'increments scryfall_id sequentially' do
      card1 = create(:card)
      card2 = create(:card)
      expect(card2.scryfall_id).not_to eq(card1.scryfall_id)
    end
  end

  # Database
  describe 'database' do
    subject { create(:card) }

    it 'persists attributes to database' do
      reloaded = Card.find(subject.id)
      expect(reloaded.name).to eq(subject.name)
      expect(reloaded.scryfall_id).to eq(subject.scryfall_id)
    end

    it 'enforces foreign key constraint' do
      subject.card_set_id = 999999
      expect { subject.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  # Edge cases
  describe 'edge cases' do
    context 'with very long name' do
      subject { build(:card, name: 'A' * 1000) }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'with special characters in name' do
      subject { build(:card, name: "L̈̈ightning Bolt // Bolt Upheavaⅼ") }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'with emoji in oracle_text' do
      subject { build(:card, oracle_text: 'This card is 🔥 awesome') }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'with collector_number that looks unusual' do
      subject { build(:card, collector_number: '★123') }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end
  end
end
