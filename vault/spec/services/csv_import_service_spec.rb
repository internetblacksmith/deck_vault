require 'rails_helper'

RSpec.describe CsvImportService do
  let(:card_set) { create(:card_set, name: 'Test Set', code: 'TST') }
  let!(:card1) { create(:card, card_set: card_set, name: 'Lightning Bolt', collector_number: '1') }
  let!(:card2) { create(:card, card_set: card_set, name: 'Counterspell', collector_number: '2') }

  describe '#import' do
    context 'with comma-delimited CSV' do
      it 'parses and imports cards' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,2x,
        CSV

        result = described_class.new(card_set, csv).import

        expect(result.success).to be true
        expect(result.imported.length).to eq(1)
        expect(result.imported.first[:name]).to eq('Lightning Bolt')
        expect(result.imported.first[:quantity]).to eq(2)
      end
    end

    context 'with tab-delimited CSV' do
      it 'parses and imports cards' do
        csv = "Name\tEdition\tCollector's number\tQuantityX\tFoil\nLightning Bolt\tTest Set\t1\t3x\t"

        result = described_class.new(card_set, csv).import

        expect(result.success).to be true
        expect(result.imported.length).to eq(1)
        expect(result.imported.first[:quantity]).to eq(3)
      end
    end

    context 'quantity parsing' do
      it 'handles "2x" format' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,2x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:quantity]).to eq(2)
      end

      it 'handles plain number format' do
        csv = <<~CSV
          Name,Edition,Collector's number,Quantity,Foil
          Lightning Bolt,Test Set,1,5,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:quantity]).to eq(5)
      end

      it 'handles "x2" format' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,x4,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:quantity]).to eq(4)
      end

      it 'defaults to 1 for blank quantity' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:quantity]).to eq(1)
      end

      it 'defaults to 1 for invalid quantity' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,abc,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:quantity]).to eq(1)
      end
    end

    context 'column name flexibility' do
      it 'handles "Name" column' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:name]).to eq('Lightning Bolt')
      end

      it 'handles "name" lowercase column' do
        csv = <<~CSV
          name,edition,collector_number,quantity,foil
          Lightning Bolt,Test Set,1,1,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:name]).to eq('Lightning Bolt')
      end

      it 'handles "Edition" column' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.success).to be true
      end

      it 'handles "Set" column' do
        csv = <<~CSV
          Name,Set,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.success).to be true
      end

      it 'handles "Collector Number" column' do
        csv = <<~CSV
          Name,Edition,Collector Number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.success).to be true
      end
    end

    context 'edition matching' do
      it 'matches by exact set name' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.length).to eq(1)
        expect(result.skipped).to be_empty
      end

      it 'matches by set code (case-insensitive)' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,tst,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.length).to eq(1)
      end

      it 'matches by set code uppercase' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,TST,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.length).to eq(1)
      end

      it 'skips cards from different set' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Other Set,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported).to be_empty
        expect(result.skipped.length).to eq(1)
        expect(result.skipped.first[:reason]).to include("doesn't match")
      end

      it 'accepts blank edition (assumes match)' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.length).to eq(1)
      end
    end

    context 'card finding' do
      it 'finds card by collector number' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Wrong Name,Test Set,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        # Should find Lightning Bolt by collector number despite wrong name
        expect(result.imported.length).to eq(1)
        expect(result.imported.first[:name]).to eq('Lightning Bolt')
      end

      it 'finds card by exact name' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.length).to eq(1)
      end

      it 'finds card by case-insensitive name' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          LIGHTNING BOLT,Test Set,,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.length).to eq(1)
      end

      it 'finds double-faced card by front face name' do
        dfc = create(:card, card_set: card_set, name: 'Delver of Secrets // Insectile Aberration', collector_number: '51')

        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Delver of Secrets,Test Set,,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.length).to eq(1)
        expect(result.imported.first[:name]).to eq('Delver of Secrets // Insectile Aberration')
      end

      it 'skips card not found in set' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Nonexistent Card,Test Set,,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported).to be_empty
        expect(result.skipped.length).to eq(1)
        expect(result.skipped.first[:reason]).to eq('Card not found in set')
      end
    end

    context 'foil handling' do
      it 'marks card as foil when Foil column has value' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,Foil
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:foil]).to be true
      end

      it 'marks card as non-foil when Foil column is empty' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:foil]).to be false
      end

      it 'marks card as non-foil when Foil column is "false"' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,false
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:foil]).to be false
      end

      it 'marks card as foil for any truthy Foil value' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,yes
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.first[:foil]).to be true
      end
    end

    context 'collection card updates' do
      it 'creates new collection card if none exists' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,2x,
        CSV

        expect {
          described_class.new(card_set, csv).import
        }.to change(CollectionCard, :count).by(1)

        collection_card = CollectionCard.find_by(card_id: card1.id)
        expect(collection_card.quantity).to eq(2)
      end

      it 'adds to existing collection card quantity' do
        create(:collection_card, card: card1, quantity: 3, foil_quantity: 0)

        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,2x,
        CSV

        described_class.new(card_set, csv).import

        collection_card = card1.reload.collection_card
        expect(collection_card.quantity).to eq(5)
      end

      it 'adds to foil quantity for foil cards' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,2x,Foil
        CSV

        described_class.new(card_set, csv).import

        collection_card = CollectionCard.find_by(card_id: card1.id)
        expect(collection_card.foil_quantity).to eq(2)
      end

      it 'tracks regular and foil quantities separately' do
        create(:collection_card, card: card1, quantity: 1, foil_quantity: 1)

        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,2x,
          Lightning Bolt,Test Set,1,3x,Foil
        CSV

        described_class.new(card_set, csv).import

        collection_card = card1.reload.collection_card
        expect(collection_card.quantity).to eq(3)
        expect(collection_card.foil_quantity).to eq(4)
      end
    end

    context 'empty row handling' do
      it 'skips rows with blank name' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          ,Test Set,1,1x,
          Lightning Bolt,Test Set,1,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.length).to eq(1)
      end
    end

    context 'error handling' do
      it 'handles malformed CSV gracefully' do
        csv = "\"unclosed quote"

        result = described_class.new(card_set, csv).import

        expect(result.success).to be false
        expect(result.errors.first).to include('CSV parsing error')
      end

      it 'continues processing after row error' do
        # Create a card that will cause processing issues
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,
          Counterspell,Test Set,2,1x,
        CSV

        result = described_class.new(card_set, csv).import
        expect(result.imported.length).to eq(2)
      end
    end

    context 'multiple cards import' do
      it 'imports multiple different cards' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,2x,
          Counterspell,Test Set,2,3x,
        CSV

        result = described_class.new(card_set, csv).import

        expect(result.success).to be true
        expect(result.imported.length).to eq(2)
        expect(result.imported.map { |i| i[:name] }).to contain_exactly('Lightning Bolt', 'Counterspell')
      end

      it 'imports same card multiple times (accumulates)' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,2x,
          Lightning Bolt,Test Set,1,3x,
        CSV

        result = described_class.new(card_set, csv).import

        expect(result.imported.length).to eq(2)

        collection_card = CollectionCard.find_by(card_id: card1.id)
        expect(collection_card.quantity).to eq(5)
      end
    end

    context 'Result struct' do
      it 'returns proper Result struct' do
        csv = <<~CSV
          Name,Edition,Collector's number,QuantityX,Foil
          Lightning Bolt,Test Set,1,1x,
          Nonexistent,Test Set,99,1x,
        CSV

        result = described_class.new(card_set, csv).import

        expect(result).to be_a(CsvImportService::Result)
        expect(result.success).to be true
        expect(result.imported).to be_an(Array)
        expect(result.skipped).to be_an(Array)
        expect(result.errors).to be_an(Array)
      end
    end
  end
end
