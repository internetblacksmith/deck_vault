require 'rails_helper'

RSpec.describe DelverCsvPreviewService do
  let!(:card_set) { create(:card_set, code: 'tst', name: 'Test Set') }
  let!(:card) { create(:card, card_set: card_set, name: 'Test Card', collector_number: '1') }

  def create_csv(rows)
    headers = "Name,Edition code,Collector's number,QuantityX,Foil,Scryfall ID\n"
    csv_content = rows.map do |row|
      "\"#{row[:name]}\",\"#{row[:edition_code]}\",\"#{row[:collector_number]}\",\"#{row[:quantity]}\",\"#{row[:foil]}\",\"#{row[:scryfall_id]}\""
    end.join("\n")
    headers + csv_content
  end

  describe '#preview' do
    context 'with valid CSV' do
      it 'returns success true with parsed cards' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.success?).to be true
        expect(result.cards.length).to eq(1)
        expect(result.cards.first.name).to eq('Test Card')
        expect(result.cards.first.quantity).to eq(2)
      end

      it 'calculates correct total count' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id },
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: 'Foil', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.total_count).to eq(5)
      end

      it 'calculates correct regular count' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id },
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: 'Foil', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.regular_count).to eq(3)
      end

      it 'calculates correct foil count' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id },
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: 'Foil', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.foil_count).to eq(2)
      end

      it 'calculates correct unique count' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id },
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: 'Foil', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.unique_count).to eq(2)
      end
    end

    context 'with found sets' do
      it 'identifies sets that exist in database' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.found_sets).to include('tst' => 'Test Set')
      end
    end

    context 'with missing sets' do
      it 'identifies sets not in database' do
        csv = create_csv([
          { name: 'Unknown Card', edition_code: 'XYZ', collector_number: '99', quantity: '1x', foil: '', scryfall_id: '' }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.missing_sets).to include('xyz')
      end
    end

    context 'foil detection' do
      it 'marks cards with Foil value as foil' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'Foil', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.cards.first.foil).to be true
      end

      it 'marks cards without Foil value as non-foil' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.cards.first.foil).to be false
      end
    end

    context 'with invalid CSV' do
      it 'returns error for empty CSV' do
        service = described_class.new("")

        result = service.preview

        expect(result.success?).to be false
        expect(result.errors).to include("CSV file is empty")
      end

      it 'returns error for non-Delver CSV' do
        csv = "Name,Set,Quantity\nCard,TST,1"

        service = described_class.new(csv)
        result = service.preview

        expect(result.success?).to be false
        expect(result.errors).to include("CSV doesn't appear to be a Delver Lens export (missing Scryfall ID column)")
      end
    end

    context 'quantity parsing' do
      it 'parses "2x" format' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.cards.first.quantity).to eq(2)
      end

      it 'parses plain number format' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '5', foil: '', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.cards.first.quantity).to eq(5)
      end

      it 'defaults to 1 for blank quantity' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '', foil: '', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.cards.first.quantity).to eq(1)
      end
    end

    context 'card existence check' do
      it 'marks found cards as found' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: card.id }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.cards.first.found).to be true
      end

      it 'marks cards in missing sets as found (will be downloaded)' do
        csv = create_csv([
          { name: 'Unknown Card', edition_code: 'XYZ', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
        ])

        service = described_class.new(csv)
        result = service.preview

        expect(result.cards.first.found).to be true
        expect(result.missing_sets).to include('xyz')
      end
    end

    context 'does not modify database' do
      it 'does not create collection cards' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '5x', foil: '', scryfall_id: card.id }
        ])

        expect {
          described_class.new(csv).preview
        }.not_to change(CollectionCard, :count)
      end

      it 'does not modify existing collection cards' do
        existing = create(:collection_card, card: card, quantity: 1)

        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '5x', foil: '', scryfall_id: card.id }
        ])

        described_class.new(csv).preview

        expect(existing.reload.quantity).to eq(1)
      end
    end

    context 'with missing or invalid field values' do
      context 'Name field' do
        it 'skips rows with blank name and blank scryfall_id' do
          csv = create_csv([
            { name: '', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards).to be_empty
        end

        it 'includes rows with blank name but valid scryfall_id' do
          csv = create_csv([
            { name: '', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.length).to eq(1)
          expect(result.cards.first.name).to eq('')
        end
      end

      context 'Edition code field' do
        it 'handles blank edition code gracefully' do
          csv = create_csv([
            { name: 'Test Card', edition_code: '', collector_number: '1', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.cards.length).to eq(1)
          expect(result.cards.first.set_code).to eq('')
        end

        it 'handles invalid edition code (not in database)' do
          csv = create_csv([
            { name: 'Unknown Card', edition_code: 'INVALID', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.missing_sets).to include('invalid')
        end
      end

      context 'Collector number field' do
        it 'handles blank collector number' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.cards.length).to eq(1)
          expect(result.cards.first.collector_number).to eq('')
        end

        it 'handles non-numeric collector number' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: 'A123', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.cards.first.collector_number).to eq('A123')
        end
      end

      context 'Quantity field' do
        it 'handles invalid quantity format (letters)' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: 'abc', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.quantity).to eq(1)
        end

        it 'handles negative quantity' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '-5', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          # Regex extracts digits, so -5 becomes 5
          expect(result.cards.first.quantity).to eq(5)
        end

        it 'handles zero quantity' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '0', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.quantity).to eq(0)
        end

        it 'handles "x2" format (number after x)' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: 'x3', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.quantity).to eq(3)
        end
      end

      context 'Foil field' do
        it 'treats "true" as foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'true', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.foil).to be true
        end

        it 'treats "false" as non-foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'false', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.foil).to be false
        end

        it 'treats "yes" as foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'yes', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.foil).to be true
        end

        it 'treats "1" as foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '1', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.foil).to be true
        end

        it 'treats random text as foil (any non-empty, non-false value)' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'something', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.foil).to be true
        end
      end

      context 'Scryfall ID field' do
        it 'handles blank scryfall_id with valid name and set' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.cards.length).to eq(1)
          # Card should be found by name + set
          expect(result.cards.first.found).to be true
        end

        it 'handles non-existent scryfall_id' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: 'non-existent-uuid' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.cards.length).to eq(1)
          # Should fall back to name + set matching
          expect(result.cards.first.found).to be true
        end

        it 'marks card as not found when no matching method works' do
          csv = create_csv([
            { name: 'Completely Unknown Card', edition_code: 'TST', collector_number: '999', quantity: '1x', foil: '', scryfall_id: 'invalid-id' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.cards.length).to eq(1)
          expect(result.cards.first.found).to be false
        end
      end
    end

    context 'edge cases' do
      context 'double-faced cards' do
        let!(:dfc_card) { create(:card, card_set: card_set, name: 'Front Side // Back Side', collector_number: '10') }

        it 'finds DFC by full name' do
          csv = create_csv([
            { name: 'Front Side // Back Side', edition_code: 'TST', collector_number: '10', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.found).to be true
        end

        it 'finds DFC by front face name only' do
          csv = create_csv([
            { name: 'Front Side', edition_code: 'TST', collector_number: '10', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.found).to be true
        end
      end

      context 'multiple rows for same card' do
        it 'creates separate entries for each row' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id },
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.length).to eq(2)
          expect(result.total_count).to eq(5)
        end

        it 'handles same card as regular and foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id },
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'Foil', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.regular_count).to eq(2)
          expect(result.foil_count).to eq(1)
        end
      end

      context 'case sensitivity' do
        it 'handles uppercase set code' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.found_sets.keys).to include('tst')
        end

        it 'handles lowercase set code' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'tst', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.found_sets.keys).to include('tst')
        end

        it 'handles mixed case set code' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TsT', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.found_sets.keys).to include('tst')
        end
      end

      context 'whitespace handling' do
        it 'handles leading/trailing spaces in name' do
          csv = create_csv([
            { name: '  Test Card  ', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.name).to eq('  Test Card  ')
          expect(result.cards.first.found).to be true
        end

        it 'handles spaces in set code' do
          csv = create_csv([
            { name: 'Test Card', edition_code: ' TST ', collector_number: '1', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          # Service should still find the card by scryfall_id
          expect(result.cards.first.found).to be true
        end
      end

      context 'special characters in card names' do
        let!(:special_card) { create(:card, card_set: card_set, name: 'Æther Vial', collector_number: '20') }

        it 'handles unicode characters' do
          csv = create_csv([
            { name: 'Æther Vial', edition_code: 'TST', collector_number: '20', quantity: '1x', foil: '', scryfall_id: special_card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.name).to eq('Æther Vial')
          expect(result.cards.first.found).to be true
        end

        let!(:apostrophe_card) { create(:card, card_set: card_set, name: "Collector's Vault", collector_number: '21') }

        it 'handles apostrophes in names' do
          csv = create_csv([
            { name: "Collector's Vault", edition_code: 'TST', collector_number: '21', quantity: '1x', foil: '', scryfall_id: apostrophe_card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.found).to be true
        end
      end

      context 'mixed valid and invalid rows' do
        it 'continues processing after invalid rows' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id },
            { name: '', edition_code: '', collector_number: '', quantity: '', foil: '', scryfall_id: '' },
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.cards.length).to eq(2)
          expect(result.total_count).to eq(5)
        end

        it 'processes valid rows even when some cards not found' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id },
            { name: 'Unknown Card', edition_code: 'XXX', collector_number: '99', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.cards.length).to eq(2)
          expect(result.cards.first.found).to be true
          expect(result.cards.last.found).to be true  # Missing set = will be downloaded
        end
      end

      context 'very large quantities' do
        it 'handles large quantity values' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '99999x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.preview

          expect(result.cards.first.quantity).to eq(99999)
          expect(result.total_count).to eq(99999)
        end
      end

      context 'malformed CSV edge cases' do
        it 'handles CSV with extra columns' do
          csv = "Name,Edition code,Collector's number,QuantityX,Foil,Scryfall ID,Extra Column\n"
          csv += "\"Test Card\",\"TST\",\"1\",\"2x\",\"\",\"#{card.id}\",\"extra data\""

          service = described_class.new(csv)
          result = service.preview

          expect(result.success?).to be true
          expect(result.cards.length).to eq(1)
        end

        it 'handles CSV with fewer columns (missing values)' do
          csv = "Name,Edition code,Collector's number,QuantityX,Foil,Scryfall ID\n"
          csv += "\"Test Card\",\"TST\",\"1\""

          service = described_class.new(csv)
          result = service.preview

          # Should handle gracefully - missing values treated as blank
          expect(result.success?).to be true
        end
      end
    end
  end
end
