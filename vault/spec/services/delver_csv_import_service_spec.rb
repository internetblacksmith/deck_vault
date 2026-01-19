require 'rails_helper'

RSpec.describe DelverCsvImportService do
  let!(:card_set) { create(:card_set, code: 'tst', name: 'Test Set') }
  let!(:card) { create(:card, card_set: card_set, name: 'Test Card', collector_number: '1') }

  def create_csv(rows)
    headers = "Name,Edition code,Collector's number,QuantityX,Foil,Scryfall ID\n"
    csv_content = rows.map do |row|
      "\"#{row[:name]}\",\"#{row[:edition_code]}\",\"#{row[:collector_number]}\",\"#{row[:quantity]}\",\"#{row[:foil]}\",\"#{row[:scryfall_id]}\""
    end.join("\n")
    headers + csv_content
  end

  describe '#import' do
    context 'needs_placement_at behavior' do
      context 'in add mode (default)' do
        it 'sets needs_placement_at when importing new cards' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id }
          ])

          before_import = Time.current
          service = described_class.new(csv, mode: :add)
          service.import
          after_import = Time.current

          collection_card = CollectionCard.find_by(card_id: card.id)
          expect(collection_card.needs_placement_at).to be_between(before_import, after_import)
        end

        it 'sets needs_placement_at when adding to existing quantities' do
          existing = create(:collection_card, card: card, quantity: 1, needs_placement_at: nil)

          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id }
          ])

          before_import = Time.current
          service = described_class.new(csv, mode: :add)
          service.import
          after_import = Time.current

          existing.reload
          expect(existing.needs_placement_at).to be_between(before_import, after_import)
          expect(existing.quantity).to eq(3)
        end

        it 'sets needs_placement_at for foil imports' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: 'Foil', scryfall_id: card.id }
          ])

          before_import = Time.current
          service = described_class.new(csv, mode: :add)
          service.import
          after_import = Time.current

          collection_card = CollectionCard.find_by(card_id: card.id)
          expect(collection_card.needs_placement_at).to be_between(before_import, after_import)
          expect(collection_card.foil_quantity).to eq(3)
        end
      end

      context 'in replace mode' do
        it 'does NOT set needs_placement_at when replacing' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv, mode: :replace)
          service.import

          collection_card = CollectionCard.find_by(card_id: card.id)
          expect(collection_card.needs_placement_at).to be_nil
        end

        it 'does NOT clear existing needs_placement_at when replacing' do
          existing = create(:collection_card, card: card, quantity: 5, needs_placement_at: 1.day.ago)
          original_timestamp = existing.needs_placement_at

          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv, mode: :replace)
          service.import

          existing.reload
          expect(existing.quantity).to eq(2)
          expect(existing.needs_placement_at).to eq(original_timestamp)
        end

        it 'does NOT set needs_placement_at for foil replacements' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: 'Foil', scryfall_id: card.id }
          ])

          service = described_class.new(csv, mode: :replace)
          service.import

          collection_card = CollectionCard.find_by(card_id: card.id)
          expect(collection_card.needs_placement_at).to be_nil
        end
      end
    end

    context 'import statistics' do
      it 'returns correct imported count' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id }
        ])

        service = described_class.new(csv, mode: :add)
        result = service.import

        expect(result[:imported]).to eq(3)
      end

      it 'returns correct foils_imported count' do
        csv = create_csv([
          { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: 'Foil', scryfall_id: card.id }
        ])

        service = described_class.new(csv, mode: :add)
        result = service.import

        expect(result[:foils_imported]).to eq(2)
      end
    end

    context 'with invalid CSV structure' do
      it 'returns error for empty CSV' do
        service = described_class.new("")
        result = service.import

        expect(result.success?).to be false
        expect(result.errors).to include("CSV file is empty")
      end

      it 'returns error for non-Delver CSV (missing Scryfall ID column)' do
        csv = "Name,Set,Quantity\nCard,TST,1"

        service = described_class.new(csv)
        result = service.import

        expect(result.success?).to be false
        expect(result.errors).to include("CSV doesn't appear to be a Delver Lens export (missing Scryfall ID column)")
      end
    end

    context 'with missing or invalid field values' do
      context 'Name field' do
        it 'skips rows with blank name and blank scryfall_id' do
          csv = create_csv([
            { name: '', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(0)
          expect(CollectionCard.count).to eq(0)
        end

        it 'imports rows with blank name but valid scryfall_id' do
          csv = create_csv([
            { name: '', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(2)
          expect(CollectionCard.find_by(card_id: card.id).quantity).to eq(2)
        end
      end

      context 'Edition code field' do
        it 'handles blank edition code when scryfall_id is valid' do
          csv = create_csv([
            { name: 'Test Card', edition_code: '', collector_number: '1', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.success?).to be true
          expect(result.imported).to eq(1)
        end

        it 'skips cards with invalid edition code and no scryfall_id match' do
          csv = create_csv([
            { name: 'Unknown Card', edition_code: 'INVALID', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.skipped).to eq(1)
          expect(result.imported).to eq(0)
        end
      end

      context 'Collector number field' do
        it 'handles blank collector number when scryfall_id is valid' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.success?).to be true
          expect(result.imported).to eq(1)
        end

        it 'handles non-numeric collector number' do
          card_with_alpha = create(:card, card_set: card_set, name: 'Alpha Card', collector_number: 'A123')

          csv = create_csv([
            { name: 'Alpha Card', edition_code: 'TST', collector_number: 'A123', quantity: '1x', foil: '', scryfall_id: card_with_alpha.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.success?).to be true
          expect(result.imported).to eq(1)
        end
      end

      context 'Quantity field' do
        it 'handles invalid quantity format (letters) - defaults to 1' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: 'abc', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
          expect(CollectionCard.find_by(card_id: card.id).quantity).to eq(1)
        end

        it 'handles negative quantity (extracts digits)' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '-5', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(5)
          expect(CollectionCard.find_by(card_id: card.id).quantity).to eq(5)
        end

        it 'handles zero quantity' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '0', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(0)
        end

        it 'handles "x3" format (number after x)' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: 'x3', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(3)
          expect(CollectionCard.find_by(card_id: card.id).quantity).to eq(3)
        end

        it 'handles blank quantity - defaults to 1' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
          expect(CollectionCard.find_by(card_id: card.id).quantity).to eq(1)
        end
      end

      context 'Foil field' do
        it 'treats "Foil" as foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'Foil', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.foils_imported).to eq(1)
          expect(CollectionCard.find_by(card_id: card.id).foil_quantity).to eq(1)
        end

        it 'treats "true" as foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'true', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.foils_imported).to eq(1)
        end

        it 'treats "false" as non-foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'false', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
          expect(result.foils_imported).to eq(0)
        end

        it 'treats empty string as non-foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
          expect(result.foils_imported).to eq(0)
        end

        it 'treats "yes" as foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'yes', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.foils_imported).to eq(1)
        end

        it 'treats "1" as foil' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '1', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.foils_imported).to eq(1)
        end
      end

      context 'Scryfall ID field' do
        it 'finds card by scryfall_id when provided' do
          csv = create_csv([
            { name: 'Wrong Name', edition_code: 'WRONG', collector_number: '999', quantity: '1x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
          expect(CollectionCard.find_by(card_id: card.id)).to be_present
        end

        it 'falls back to name + set when scryfall_id is blank' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
          expect(CollectionCard.find_by(card_id: card.id)).to be_present
        end

        it 'falls back to name + set when scryfall_id is invalid' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: 'invalid-uuid' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
          expect(CollectionCard.find_by(card_id: card.id)).to be_present
        end

        it 'skips card when no matching method works' do
          csv = create_csv([
            { name: 'Completely Unknown Card', edition_code: 'TST', collector_number: '999', quantity: '1x', foil: '', scryfall_id: 'invalid-id' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.skipped).to eq(1)
          expect(result.imported).to eq(0)
        end
      end
    end

    context 'edge cases' do
      context 'double-faced cards' do
        let!(:dfc_card) { create(:card, card_set: card_set, name: 'Front Side // Back Side', collector_number: '10') }

        it 'imports DFC by full name' do
          csv = create_csv([
            { name: 'Front Side // Back Side', edition_code: 'TST', collector_number: '10', quantity: '2x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(2)
          expect(CollectionCard.find_by(card_id: dfc_card.id).quantity).to eq(2)
        end

        it 'imports DFC by front face name only' do
          csv = create_csv([
            { name: 'Front Side', edition_code: 'TST', collector_number: '10', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
          expect(CollectionCard.find_by(card_id: dfc_card.id)).to be_present
        end
      end

      context 'multiple rows for same card' do
        it 'accumulates quantities in add mode' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id },
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv, mode: :add)
          result = service.import

          expect(result.imported).to eq(5)
          expect(CollectionCard.find_by(card_id: card.id).quantity).to eq(5)
        end

        it 'accumulates regular and foil separately' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id },
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: 'Foil', scryfall_id: card.id }
          ])

          service = described_class.new(csv, mode: :add)
          result = service.import

          collection_card = CollectionCard.find_by(card_id: card.id)
          expect(collection_card.quantity).to eq(2)
          expect(collection_card.foil_quantity).to eq(1)
        end

        it 'replaces quantities per row in replace mode' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id },
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '5x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv, mode: :replace)
          result = service.import

          # In replace mode, second row overwrites first
          expect(CollectionCard.find_by(card_id: card.id).quantity).to eq(5)
        end
      end

      context 'case sensitivity' do
        it 'handles uppercase set code' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
        end

        it 'handles lowercase set code' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'tst', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
        end

        it 'handles mixed case set code' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TsT', collector_number: '1', quantity: '1x', foil: '', scryfall_id: '' }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
        end
      end

      context 'special characters in card names' do
        let!(:special_card) { create(:card, card_set: card_set, name: 'Æther Vial', collector_number: '20') }

        it 'handles unicode characters' do
          csv = create_csv([
            { name: 'Æther Vial', edition_code: 'TST', collector_number: '20', quantity: '1x', foil: '', scryfall_id: special_card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
          expect(CollectionCard.find_by(card_id: special_card.id)).to be_present
        end

        let!(:apostrophe_card) { create(:card, card_set: card_set, name: "Collector's Vault", collector_number: '21') }

        it 'handles apostrophes in names' do
          csv = create_csv([
            { name: "Collector's Vault", edition_code: 'TST', collector_number: '21', quantity: '1x', foil: '', scryfall_id: apostrophe_card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(1)
        end
      end

      context 'mixed valid and invalid rows' do
        it 'continues processing after skipped rows' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: '', scryfall_id: card.id },
            { name: 'Unknown', edition_code: 'TST', collector_number: '999', quantity: '1x', foil: '', scryfall_id: 'bad-id' },
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv, mode: :add)
          result = service.import

          expect(result.imported).to eq(5)
          expect(result.skipped).to eq(1)
          expect(CollectionCard.find_by(card_id: card.id).quantity).to eq(5)
        end
      end

      context 'very large quantities' do
        it 'handles large quantity values' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '99999x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv)
          result = service.import

          expect(result.imported).to eq(99999)
          expect(CollectionCard.find_by(card_id: card.id).quantity).to eq(99999)
        end
      end

      context 'malformed CSV edge cases' do
        it 'handles CSV with extra columns' do
          csv = "Name,Edition code,Collector's number,QuantityX,Foil,Scryfall ID,Extra Column\n"
          csv += "\"Test Card\",\"TST\",\"1\",\"2x\",\"\",\"#{card.id}\",\"extra data\""

          service = described_class.new(csv)
          result = service.import

          expect(result.success?).to be true
          expect(result.imported).to eq(2)
        end

        it 'handles CSV with fewer columns (missing values)' do
          csv = "Name,Edition code,Collector's number,QuantityX,Foil,Scryfall ID\n"
          csv += "\"Test Card\",\"TST\",\"1\""

          service = described_class.new(csv)
          result = service.import

          # Should handle gracefully - finds by name+set, defaults to quantity 1
          expect(result.success?).to be true
        end
      end

      context 'adding to existing collection' do
        let!(:existing_collection) { create(:collection_card, card: card, quantity: 5, foil_quantity: 2) }

        it 'adds to existing quantities in add mode' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '3x', foil: '', scryfall_id: card.id }
          ])

          service = described_class.new(csv, mode: :add)
          result = service.import

          existing_collection.reload
          expect(existing_collection.quantity).to eq(8)  # 5 + 3
          expect(existing_collection.foil_quantity).to eq(2)  # unchanged
        end

        it 'adds foils to existing foil quantities' do
          csv = create_csv([
            { name: 'Test Card', edition_code: 'TST', collector_number: '1', quantity: '2x', foil: 'Foil', scryfall_id: card.id }
          ])

          service = described_class.new(csv, mode: :add)
          result = service.import

          existing_collection.reload
          expect(existing_collection.quantity).to eq(5)  # unchanged
          expect(existing_collection.foil_quantity).to eq(4)  # 2 + 2
        end
      end
    end
  end
end
