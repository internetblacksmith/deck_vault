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
    it { is_expected.to validate_presence_of(:id) }
    it { is_expected.to validate_uniqueness_of(:id).case_insensitive }

    context 'when name is missing' do
      before { subject.name = nil }
      it { is_expected.not_to be_valid }
    end

    context 'when id is missing' do
      before { subject.id = nil }
      it { is_expected.not_to be_valid }
    end

    context 'when id already exists' do
      let!(:existing_card) { create(:card) }

      it 'is not valid' do
        duplicate = Card.new(
          id: existing_card.id,
          name: 'Duplicate Card',
          card_set: existing_card.card_set
        )
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:id]).to include('has already been taken')
      end
    end

    context 'when all required fields are present' do
      subject { build(:card, name: 'Lightning Bolt', id: '12345678-1234-1234-1234-123456789012') }
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

      it 'returns hash with id, name, and image_uris' do
        result = subject.to_image_hash
        expect(result[:id]).to eq(subject.id)
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
    it { is_expected.to respond_to(:id) }
    it { is_expected.to respond_to(:scryfall_id) }  # alias for id
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
      expect(subject.id).to be_present
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

    it 'increments id sequentially' do
      card1 = create(:card)
      card2 = create(:card)
      expect(card2.id).not_to eq(card1.id)
    end
  end

  # Database
  describe 'database' do
    subject { create(:card) }

    it 'persists attributes to database' do
      reloaded = Card.find(subject.id)
      expect(reloaded.name).to eq(subject.name)
      expect(reloaded.id).to eq(subject.id)
    end

    it 'enforces foreign key constraint' do
      subject.card_set_id = 999999
      expect { subject.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  # Double-faced card methods
  describe '#double_faced?' do
    context 'when card has back_image_uris' do
      subject { create(:card, back_image_uris: { normal: 'https://example.com/back.jpg' }.to_json) }

      it 'returns true' do
        expect(subject.double_faced?).to be true
      end
    end

    context 'when card has no back_image_uris' do
      subject { create(:card, back_image_uris: nil) }

      it 'returns false' do
        expect(subject.double_faced?).to be false
      end
    end

    context 'when back_image_uris is empty string' do
      subject { create(:card, back_image_uris: '') }

      it 'returns false' do
        expect(subject.double_faced?).to be false
      end
    end
  end

  describe '#to_back_image_hash' do
    context 'when card is double-faced' do
      subject do
        create(:card,
          back_image_uris: { normal: 'https://example.com/back.jpg', small: 'https://example.com/back_small.jpg' }.to_json)
      end

      it 'returns hash with id, name, and back image_uris' do
        result = subject.to_back_image_hash
        expect(result[:id]).to eq(subject.id)
        expect(result[:name]).to eq(subject.name)
        expect(result[:image_uris]).to be_a(Hash)
      end

      it 'parses back image_uris JSON correctly' do
        result = subject.to_back_image_hash
        expect(result[:image_uris]['normal']).to eq('https://example.com/back.jpg')
        expect(result[:image_uris]['small']).to eq('https://example.com/back_small.jpg')
      end
    end

    context 'when card is not double-faced' do
      subject { create(:card, back_image_uris: nil) }

      it 'returns nil' do
        expect(subject.to_back_image_hash).to be_nil
      end
    end
  end

  # Foil/Nonfoil attributes
  describe 'foil and nonfoil attributes' do
    describe '#foil' do
      it 'defaults to true' do
        card = create(:card)
        expect(card.foil).to be true
      end

      it 'can be set to false' do
        card = create(:card, foil: false)
        expect(card.foil).to be false
      end
    end

    describe '#nonfoil' do
      it 'defaults to true' do
        card = create(:card)
        expect(card.nonfoil).to be true
      end

      it 'can be set to false' do
        card = create(:card, nonfoil: false)
        expect(card.nonfoil).to be false
      end
    end

    context 'foil-only card' do
      subject { create(:card, foil: true, nonfoil: false) }

      it 'is foil but not nonfoil' do
        expect(subject.foil).to be true
        expect(subject.nonfoil).to be false
      end
    end

    context 'nonfoil-only card' do
      subject { create(:card, foil: false, nonfoil: true) }

      it 'is nonfoil but not foil' do
        expect(subject.foil).to be false
        expect(subject.nonfoil).to be true
      end
    end
  end

  # Back image path attribute
  describe 'back_image_path attribute' do
    it { is_expected.to respond_to(:back_image_path) }
    it { is_expected.to respond_to(:back_image_uris) }

    context 'with back image downloaded' do
      subject { create(:card, back_image_path: 'card_images/abc123_back.jpg') }

      it 'stores the back image path' do
        expect(subject.back_image_path).to eq('card_images/abc123_back.jpg')
      end
    end
  end

  # Callback: delete_image_file
  describe '#delete_image_file callback' do
    let(:card_set) { create(:card_set) }
    let(:image_path) { 'card_images/test-card.jpg' }
    let(:full_path) { Rails.root.join('storage', image_path) }

    def find_card(card)
      Card.includes(:collection_card, :card_set).find(card.id)
    end

    context 'when card has an image_path' do
      let!(:card) { create(:card, card_set: card_set, image_path: image_path) }

      before do
        # Create a fake image file
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, 'fake image data')
      end

      after do
        FileUtils.rm_f(full_path)
      end

      it 'deletes the image file when card is destroyed' do
        expect(File.exist?(full_path)).to be true
        find_card(card).destroy
        expect(File.exist?(full_path)).to be false
      end
    end

    context 'when card has no image_path' do
      let!(:card) { create(:card, card_set: card_set, image_path: nil) }

      it 'does not raise error on destroy' do
        expect { find_card(card).destroy }.not_to raise_error
      end
    end

    context 'when image file does not exist' do
      let!(:card) { create(:card, card_set: card_set, image_path: image_path) }

      it 'does not raise error on destroy' do
        expect(File.exist?(full_path)).to be false
        expect { find_card(card).destroy }.not_to raise_error
      end
    end

    context 'when file deletion raises an error' do
      let!(:card) { create(:card, card_set: card_set, image_path: image_path) }

      before do
        allow(File).to receive(:exist?).with(full_path).and_return(true)
        allow(FileUtils).to receive(:rm_f).and_raise(Errno::EACCES.new('Permission denied'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Error deleting image file/)
        find_card(card).destroy
      end

      it 'does not prevent card destruction' do
        allow(Rails.logger).to receive(:error) # Suppress logging for this test
        find_card(card).destroy
        expect(Card.find_by(id: card.id)).to be_nil
      end
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
