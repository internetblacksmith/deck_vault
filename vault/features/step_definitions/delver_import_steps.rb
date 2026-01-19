# Delver import step definitions

When('I visit the collection index page') do
  visit card_sets_path
end

Then('I should see the {string} button') do |button_text|
  expect(page).to have_button(button_text)
end

# "I click {string}" is defined in binder_steps.rb

Then('I should see the Delver import panel') do
  expect(page).to have_css('[data-backup-target="delverPanel"]', visible: true)
end

Then('I should not see the Delver import panel') do
  expect(page).to have_css('[data-backup-target="delverPanel"]', visible: false)
end

Then('I should see the {string} option selected') do |option_text|
  within('[data-backup-target="delverPanel"]') do
    radio = find('input[type="radio"][value="add"]')
    expect(radio).to be_checked
  end
end

Given('I have a Delver CSV file with:') do |table|
  # Build CSV content from table
  headers = "Name,Edition code,Collector's number,QuantityX,Foil,Scryfall ID"
  rows = table.hashes.map do |row|
    # Use the card's actual ID if it exists
    card = Card.find_by(name: row['name'])
    scryfall_id = card&.id || row['scryfall_id']

    [
      "\"#{row['name']}\"",
      "\"#{row['edition_code']}\"",
      "\"#{row['collector_number']}\"",
      "\"#{row['quantity']}\"",
      "\"#{row['foil']}\"",
      "\"#{scryfall_id}\""
    ].join(',')
  end

  @delver_csv_content = ([ headers ] + rows).join("\n")

  # Create a temp file
  @delver_csv_file = Tempfile.new([ 'delver_export', '.csv' ])
  @delver_csv_file.write(@delver_csv_content)
  @delver_csv_file.flush
end

When('I attach the Delver CSV file') do
  within('[data-backup-target="delverPanel"]') do
    attach_file('csv_files[]', @delver_csv_file.path)
  end
end

When('I select {string}') do |option_text|
  within('[data-backup-target="delverPanel"]') do
    choose(option_text)
  end
end

Then('I should see {string}') do |text|
  expect(page).to have_content(text)
end

Then('{string} should have quantity {int}') do |card_name, expected_quantity|
  card = Card.find_by!(name: card_name)
  collection_card = CollectionCard.find_by(card_id: card.id)
  expect(collection_card&.quantity.to_i).to eq(expected_quantity)
end

Given('Scryfall will provide set {string} with name {string}') do |set_code, set_name|
  # Stub the Scryfall API endpoints using WebMock
  stub_request(:get, "https://api.scryfall.com/sets/#{set_code}")
    .to_return(
      status: 200,
      body: {
        code: set_code,
        name: set_name,
        released_at: "2016-04-08",
        card_count: 297,
        set_type: "expansion"
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

  stub_request(:get, /api\.scryfall\.com\/cards\/search/)
    .with(query: hash_including({}))
    .to_return(
      status: 200,
      body: {
        has_more: false,
        data: [
          {
            id: "archangel-avacyn-1",
            name: "Archangel Avacyn",
            mana_cost: "{3}{W}{W}",
            type_line: "Legendary Creature - Angel",
            oracle_text: "Flying, vigilance...",
            rarity: "mythic",
            collector_number: "5",
            image_uris: { normal: "https://example.com/avacyn.jpg", small: "https://example.com/avacyn-small.jpg" },
            foil: true,
            nonfoil: true
          }
        ]
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end

Given('I have a Delver CSV file for missing set:') do |table|
  # Build CSV content from table (without looking up cards since they don't exist yet)
  headers = "Name,Edition code,Collector's number,QuantityX,Foil,Scryfall ID"
  rows = table.hashes.map do |row|
    [
      "\"#{row['name']}\"",
      "\"#{row['edition_code']}\"",
      "\"#{row['collector_number']}\"",
      "\"#{row['quantity']}\"",
      "\"#{row['foil']}\"",
      "\"#{row['scryfall_id']}\""
    ].join(',')
  end

  @delver_csv_content = ([ headers ] + rows).join("\n")

  # Create a temp file
  @delver_csv_file = Tempfile.new([ 'delver_export', '.csv' ])
  @delver_csv_file.write(@delver_csv_content)
  @delver_csv_file.flush
end

Then('{string} should need placement') do |card_name|
  card = Card.find_by!(name: card_name)
  collection_card = CollectionCard.find_by(card_id: card.id)
  expect(collection_card).not_to be_nil
  expect(collection_card.needs_placement_at).not_to be_nil
end

Then('{string} should not need placement') do |card_name|
  card = Card.find_by!(name: card_name)
  collection_card = CollectionCard.find_by(card_id: card.id)
  # Either no collection_card exists, or needs_placement_at is nil
  expect(collection_card&.needs_placement_at).to be_nil
end

# Preview modal steps
Then('I should see the import preview modal') do
  expect(page).to have_css('[data-delver-import-target="modal"]', visible: true, wait: 5)
end

Then('I should not see the import preview modal') do
  expect(page).to have_css('[data-delver-import-target="modal"]', visible: false)
end

Then('I should see {string} as the total count') do |count|
  within('[data-delver-import-target="modal"]') do
    expect(page).to have_css('.preview-stat-value', text: count)
  end
end

Then('I should see {string} as the regular count') do |count|
  within('[data-delver-import-target="modal"]') do
    stats = all('.preview-stat')
    regular_stat = stats[1] # Second stat is regular count
    expect(regular_stat).to have_css('.preview-stat-value', text: count)
  end
end

Then('I should see {string} as the foil count') do |count|
  within('[data-delver-import-target="modal"]') do
    stats = all('.preview-stat')
    foil_stat = stats[2] # Third stat is foil count
    expect(foil_stat).to have_css('.preview-stat-value', text: count)
  end
end

Then('I should see {string} in the preview') do |text|
  within('[data-delver-import-target="modal"]') do
    expect(page).to have_content(text)
  end
end

Then('I should see {string} in the missing sets warning') do |set_code|
  within('[data-delver-import-target="modal"]') do
    expect(page).to have_css('.preview-warning', text: set_code)
  end
end

When('I click {string} in the modal') do |button_text|
  within('[data-delver-import-target="modal"]') do
    click_button(button_text)
  end
end

When('I confirm the import') do
  within('[data-delver-import-target="modal"]') do
    click_button('Confirm Import')
  end
end

Given('I have an invalid non-CSV file') do
  @invalid_file = Tempfile.new([ 'invalid', '.json' ])
  @invalid_file.write('{"not": "a csv"}')
  @invalid_file.flush
end

When('I attach the invalid file') do
  within('[data-backup-target="delverPanel"]') do
    attach_file('csv_files[]', @invalid_file.path)
  end
end

When('I press the Escape key') do
  page.driver.browser.action.send_keys(:escape).perform
end

After do
  @invalid_file&.close
  @invalid_file&.unlink
  @delver_csv_file&.close
  @delver_csv_file&.unlink
end
