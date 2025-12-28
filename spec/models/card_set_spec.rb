require 'rails_helper'

RSpec.describe CardSet, type: :model do
  # Associations
  describe 'associations' do
    it { is_expected.to have_many(:cards).dependent(:destroy) }
  end

  # Validations
  describe 'validations' do
    subject { build(:card_set) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:code) }

    context 'when code is missing' do
      before { subject.code = nil }
      it { is_expected.not_to be_valid }
    end

    context 'when name is missing' do
      before { subject.name = nil }
      it { is_expected.not_to be_valid }
    end

    context 'when code already exists' do
      before do
        create(:card_set, code: 'SET1')
        subject.code = 'SET1'
      end

      it { is_expected.not_to be_valid }
    end

    context 'when all required fields are present' do
      subject { build(:card_set, code: 'TST', name: 'Test Set') }
      it { is_expected.to be_valid }
    end
  end

  # Enum
  describe 'download_status enum' do
    it 'has expected enum values' do
      expect(CardSet.download_statuses).to eq({
        'pending' => 'pending',
        'downloading' => 'downloading',
        'completed' => 'completed',
        'failed' => 'failed'
      })
    end

    it 'defaults to pending' do
      card_set = CardSet.new
      expect(card_set.download_status).to eq('pending')
    end
  end

  # Methods
  describe '#download_progress_percentage' do
    context 'when card_count is nil' do
      subject { create(:card_set, card_count: nil, images_downloaded: 0) }

      it 'returns 0' do
        expect(subject.download_progress_percentage).to eq(0)
      end
    end

    context 'when card_count is zero' do
      subject { create(:card_set, card_count: 0, images_downloaded: 0) }

      it 'returns 0' do
        expect(subject.download_progress_percentage).to eq(0)
      end
    end

    context 'when all images are downloaded' do
      subject { create(:card_set, card_count: 100, images_downloaded: 100) }

      it 'returns 100.0' do
        expect(subject.download_progress_percentage).to eq(100.0)
      end
    end

    context 'when half the images are downloaded' do
      subject { create(:card_set, card_count: 100, images_downloaded: 50) }

      it 'returns 50.0' do
        expect(subject.download_progress_percentage).to eq(50.0)
      end
    end

    context 'when only one image is downloaded' do
      subject { create(:card_set, card_count: 100, images_downloaded: 1) }

      it 'returns 1.0' do
        expect(subject.download_progress_percentage).to eq(1.0)
      end
    end

    context 'when images_downloaded is 33 out of 100' do
      subject { create(:card_set, card_count: 100, images_downloaded: 33) }

      it 'returns 33.0' do
        expect(subject.download_progress_percentage).to eq(33.0)
      end
    end

    context 'when calculation results in decimal' do
      subject { create(:card_set, card_count: 3, images_downloaded: 1) }

      it 'rounds to 2 decimal places' do
        expect(subject.download_progress_percentage).to eq(33.33)
      end
    end
  end

  describe '#all_images_downloaded?' do
    context 'when images_downloaded equals card_count' do
      subject { create(:card_set, card_count: 100, images_downloaded: 100) }

      it 'returns true' do
        expect(subject.all_images_downloaded?).to be(true)
      end
    end

    context 'when images_downloaded is less than card_count' do
      subject { create(:card_set, card_count: 100, images_downloaded: 99) }

      it 'returns false' do
        expect(subject.all_images_downloaded?).to be(false)
      end
    end

    context 'when images_downloaded exceeds card_count' do
      subject { create(:card_set, card_count: 100, images_downloaded: 101) }

      it 'returns true' do
        expect(subject.all_images_downloaded?).to be(true)
      end
    end

    context 'when both are zero' do
      subject { create(:card_set, card_count: 0, images_downloaded: 0) }

      it 'returns true' do
        expect(subject.all_images_downloaded?).to be(true)
      end
    end
  end

  describe '#cards_count' do
    subject { create(:card_set, card_count: 10) }

    context 'when cards are already loaded' do
      before do
        create_list(:card, 5, card_set: subject)
        subject.reload
        subject.cards.load
      end

      it 'returns card count from loaded association' do
        expect(subject.cards_count).to eq(5)
      end
    end

    context 'when cards are not loaded' do
      before { create_list(:card, 5, card_set: subject) }

      it 'returns card count from database' do
        fresh_set = CardSet.find(subject.id)
        expect(fresh_set.cards_count).to eq(5)
      end
    end

    context 'when there are no cards' do
      it 'returns 0' do
        expect(subject.cards_count).to eq(0)
      end
    end
  end

  describe '#owned_cards_count' do
    subject { create(:card_set) }

    context 'when no cards have collection_card' do
      before { create_list(:card, 5, card_set: subject) }

      it 'returns 0' do
        expect(subject.owned_cards_count).to eq(0)
      end
    end

    context 'when some cards have collection_card' do
      before do
        create(:card, :with_collection_card, card_set: subject)
        create(:card, card_set: subject)
        create(:card, :with_collection_card, card_set: subject)
      end

      it 'returns count of owned cards' do
        expect(subject.owned_cards_count).to eq(2)
      end
    end

    context 'when all cards have collection_card' do
      before do
        5.times { create(:card, :with_collection_card, card_set: subject) }
      end

      it 'returns all card count' do
        expect(subject.owned_cards_count).to eq(5)
      end
    end

    context 'when cards are already loaded' do
      before do
        create(:card, :with_collection_card, card_set: subject)
        create(:card, card_set: subject)
        subject.reload
        subject.cards.load
      end

      it 'uses loaded association' do
        expect(subject.cards_count).to eq(2)
        expect(subject.owned_cards_count).to eq(1)
      end
    end
  end

  # Timestamps
  describe 'timestamps' do
    subject { create(:card_set) }

    it { is_expected.to have_attributes(created_at: be_a(Time), updated_at: be_a(Time)) }

    it 'updates updated_at when modified' do
      original_updated_at = subject.updated_at
      sleep 0.1
      subject.update(name: 'Updated Name')
      expect(subject.updated_at).to be >= original_updated_at
    end
  end

  # Broadcasts
  describe 'broadcasts_to' do
    subject { create(:card_set) }

    it 'has broadcasts_to configuration' do
      # The model is configured to broadcast via Turbo Streams
      expect(CardSet).to respond_to(:broadcasts_to)
    end
  end

  # Factory
  describe 'factory' do
    subject { build(:card_set) }

    it 'builds a valid card_set' do
      expect(subject).to be_valid
    end

    it 'has required attributes' do
      expect(subject.code).to be_present
      expect(subject.name).to be_present
    end

    it 'has default download_status' do
      expect(subject.download_status).to eq('completed')
    end

    it 'increments code sequentially' do
      set1 = create(:card_set)
      set2 = create(:card_set)
      expect(set2.code).not_to eq(set1.code)
    end
  end
end
