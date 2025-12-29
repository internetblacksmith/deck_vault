require 'rails_helper'

RSpec.describe CollectionCard, type: :model do
  # Associations
  describe 'associations' do
    it { is_expected.to belong_to(:card) }
  end

  # Validations
  describe 'validations' do
    subject { build(:collection_card) }

    it { is_expected.to validate_presence_of(:card_id) }
    it { is_expected.to validate_uniqueness_of(:card_id) }

    it { is_expected.to validate_numericality_of(:quantity).is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_numericality_of(:page_number).is_greater_than(0).is_less_than_or_equal_to(200).allow_nil }

    context 'when card_id is missing' do
      before { subject.card_id = nil }
      it { is_expected.not_to be_valid }
    end

    context 'when card_id is not unique' do
      before do
        create(:collection_card)
        subject.card_id = CollectionCard.last.card_id
      end

      it { is_expected.not_to be_valid }
    end

    context 'when quantity is negative' do
      before { subject.quantity = -1 }
      it { is_expected.not_to be_valid }
    end

    context 'when quantity is zero' do
      let(:card) { create(:card) }
      let(:test_card) { build(:collection_card, card: card, quantity: 0) }
      it 'is valid' do
        expect(test_card).to be_valid
      end
    end

    context 'when quantity is positive' do
      let(:card) { create(:card) }
      let(:test_card) { build(:collection_card, card: card, quantity: 5) }
      it 'is valid' do
        expect(test_card).to be_valid
      end
    end

    context 'when quantity is nil' do
      let(:card) { create(:card) }
      let(:test_card) { build(:collection_card, card: card, quantity: nil) }
      it 'is valid' do
        expect(test_card).to be_valid
      end
    end

    context 'when page_number is 0' do
      before { subject.page_number = 0 }
      it { is_expected.not_to be_valid }
    end

    context 'when page_number is 1' do
      let(:card) { create(:card) }
      let(:test_card) { build(:collection_card, card: card, page_number: 1) }
      it 'is valid' do
        expect(test_card).to be_valid
      end
    end

    context 'when page_number is 200' do
      let(:card) { create(:card) }
      let(:test_card) { build(:collection_card, card: card, page_number: 200) }
      it 'is valid' do
        expect(test_card).to be_valid
      end
    end

    context 'when page_number is 201' do
      before { subject.page_number = 201 }
      it { is_expected.not_to be_valid }
    end

    context 'when page_number is nil' do
      let(:card) { create(:card) }
      let(:test_card) { build(:collection_card, card: card, page_number: nil) }
      it 'is valid' do
        expect(test_card).to be_valid
      end
    end

    context 'when all required fields are present' do
      let(:card) { create(:card) }
      let(:test_card) { build(:collection_card, card: card, quantity: 2, page_number: 5) }
      it 'is valid' do
        expect(test_card).to be_valid
      end
    end

    context 'with minimal required fields' do
      let(:card) { create(:card) }
      let(:test_card) { build(:collection_card, card: card) }
      it 'is valid' do
        expect(test_card).to be_valid
      end
    end
  end

  # Attributes
  describe 'attributes' do
    subject { create(:collection_card) }

    it { is_expected.to respond_to(:card_id) }
    it { is_expected.to respond_to(:quantity) }
    it { is_expected.to respond_to(:foil_quantity) }
    it { is_expected.to respond_to(:page_number) }
    it { is_expected.to respond_to(:notes) }
  end

  # Touch behavior
  describe 'touch behavior' do
    subject { create(:collection_card) }

    it 'touches associated card on update' do
      original_updated_at = subject.card.updated_at
      sleep 0.1
      subject.update(quantity: 5)
      subject.card.reload
      expect(subject.card.updated_at).to be >= original_updated_at
    end
  end

  # Timestamps
  describe 'timestamps' do
    subject { create(:collection_card) }

    it { is_expected.to have_attributes(created_at: be_a(Time), updated_at: be_a(Time)) }

    it 'updates updated_at when modified' do
      original_updated_at = subject.updated_at
      sleep 0.1
      subject.update(quantity: 3)
      expect(subject.updated_at).to be >= original_updated_at
    end
  end

  # Factory
  describe 'factory' do
    subject { create(:collection_card) }

    it 'creates a valid collection_card' do
      expect(subject).to be_valid
    end

    it 'belongs to a card' do
      expect(subject.card).to be_a(Card)
    end

    it 'has default quantity' do
      expect(subject.quantity).to eq(1)
    end

    it 'has default page_number' do
      expect(subject.page_number).to eq(1)
    end

    context 'with :multiple_copies trait' do
      subject { build(:collection_card, :multiple_copies) }

      it 'has quantity of 4' do
        expect(subject.quantity).to eq(4)
      end
    end

    context 'with :without_quantity trait' do
      subject { build(:collection_card, :without_quantity) }

      it 'has nil quantity' do
        expect(subject.quantity).to be_nil
      end
    end

    context 'with :without_page trait' do
      subject { build(:collection_card, :without_page) }

      it 'has nil page_number' do
        expect(subject.page_number).to be_nil
      end
    end

    context 'with :with_notes trait' do
      subject { build(:collection_card, :with_notes) }

      it 'has notes' do
        expect(subject.notes).to be_present
      end
    end

    context 'with :back_page trait' do
      subject { build(:collection_card, :back_page) }

      it 'has page_number of 200' do
        expect(subject.page_number).to eq(200)
      end
    end

    context 'with :with_foils trait' do
      subject { build(:collection_card, :with_foils) }

      it 'has foil_quantity of 2' do
        expect(subject.foil_quantity).to eq(2)
      end
    end

    context 'with :foil_only trait' do
      subject { build(:collection_card, :foil_only) }

      it 'has quantity of 0 and foil_quantity of 1' do
        expect(subject.quantity).to eq(0)
        expect(subject.foil_quantity).to eq(1)
      end
    end
  end

  # Database
  describe 'database' do
    subject { create(:collection_card) }

    it 'persists attributes to database' do
      reloaded = CollectionCard.find(subject.id)
      expect(reloaded.quantity).to eq(subject.quantity)
      expect(reloaded.page_number).to eq(subject.page_number)
    end

    it 'enforces foreign key constraint' do
      subject.card_id = 999999
      expect { subject.save(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'ensures unique card_id' do
      card = create(:card)
      create(:collection_card, card: card)
      expect { create(:collection_card, card: card) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  # Quantity variations
  describe 'quantity variations' do
    context 'with quantity 0' do
      subject { create(:collection_card, quantity: 0) }

      it 'persists and is valid' do
        expect(subject).to be_persisted
        expect(subject.quantity).to eq(0)
      end
    end

    context 'with quantity 1' do
      subject { create(:collection_card, quantity: 1) }

      it 'is valid' do
        expect(subject).to be_valid
        expect(subject.quantity).to eq(1)
      end
    end

    context 'with quantity 99' do
      subject { create(:collection_card, quantity: 99) }

      it 'is valid' do
        expect(subject).to be_valid
        expect(subject.quantity).to eq(99)
      end
    end

    context 'with quantity very large number' do
      let(:card) { create(:card) }
      subject { build(:collection_card, card: card, quantity: 1_000_000) }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end
  end

  # Page number variations
  describe 'page number variations' do
    context 'with page_number 1 (first page)' do
      subject { create(:collection_card, page_number: 1) }

      it 'is valid' do
        expect(subject).to be_valid
        expect(subject.page_number).to eq(1)
      end
    end

    context 'with page_number 100 (middle pages)' do
      subject { create(:collection_card, page_number: 100) }

      it 'is valid' do
        expect(subject).to be_valid
        expect(subject.page_number).to eq(100)
      end
    end

    context 'with page_number 200 (last page)' do
      subject { create(:collection_card, page_number: 200) }

      it 'is valid' do
        expect(subject).to be_valid
        expect(subject.page_number).to eq(200)
      end
    end

    context 'with page_number nil (not assigned to page)' do
      subject { create(:collection_card, page_number: nil) }

      it 'is valid' do
        expect(subject).to be_valid
        expect(subject.page_number).to be_nil
      end
    end
  end

  # Notes field
  describe 'notes field' do
    context 'with notes' do
      subject { create(:collection_card, notes: 'Signed by artist') }

      it 'stores notes' do
        expect(subject.notes).to eq('Signed by artist')
      end
    end

    context 'with nil notes' do
      subject { create(:collection_card, notes: nil) }

      it 'is valid' do
        expect(subject).to be_valid
        expect(subject.notes).to be_nil
      end
    end

    context 'with empty string notes' do
      subject { create(:collection_card, notes: '') }

      it 'is valid' do
        expect(subject).to be_valid
        expect(subject.notes).to eq('')
      end
    end

    context 'with very long notes' do
      long_notes = 'A' * 10000
      subject { create(:collection_card, notes: long_notes) }

      it 'stores long notes' do
        expect(subject.notes.length).to eq(10000)
      end
    end
  end

  # Cascade behavior
  describe 'cascade behavior' do
    context 'when card is deleted' do
      let(:card) { create(:card) }
      let(:collection_card) { create(:collection_card, card: card) }

      it 'deletes associated collection_card' do
        collection_card_id = collection_card.id
        card.destroy
        expect(CollectionCard.find_by(id: collection_card_id)).to be_nil
      end
    end
  end
end
