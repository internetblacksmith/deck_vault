# Card set step definitions

Given('a card set {string} with code {string} exists') do |name, code|
  @card_set = create(:card_set, name: name, code: code, card_count: 0, download_status: :completed)
end

Given('the set has the following cards:') do |table|
  table.hashes.each do |row|
    create(:card,
      card_set: @card_set,
      name: row['name'],
      collector_number: row['collector_number'],
      rarity: row['rarity'] || 'common'
    )
  end
  @card_set.update(card_count: @card_set.cards.count)
end

Given('I own {int} copy/copies of {string}') do |quantity, card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  collection_card = CollectionCard.find_or_initialize_by(card_id: card.id)
  collection_card.card = card
  collection_card.quantity = quantity
  collection_card.foil_quantity ||= 0
  collection_card.save!
end

Given('I own {int} foil copy/copies of {string}') do |quantity, card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  collection_card = CollectionCard.find_or_initialize_by(card_id: card.id)
  collection_card.card = card
  collection_card.quantity ||= 0
  collection_card.foil_quantity = quantity
  collection_card.save!
end

Given('the binder is configured for {int} rows and {int} columns') do |rows, columns|
  @card_set.update(binder_rows: rows, binder_columns: columns)
end

When('I visit the binder view for {string}') do |set_name|
  card_set = CardSet.find_by!(name: set_name)
  visit card_set_path(card_set, view_type: 'binder')
end

When('I visit the card set {string}') do |set_name|
  card_set = CardSet.find_by!(name: set_name)
  visit card_set_path(card_set)
end

Then('I should see the card set {string}') do |set_name|
  expect(page).to have_content(set_name)
end
