# Search and filter step definitions

When('I visit the grid view for {string}') do |set_name|
  card_set = CardSet.find_by!(name: set_name)
  visit card_set_path(card_set, view_type: 'grid')
end

When('I visit the table view for {string}') do |set_name|
  card_set = CardSet.find_by!(name: set_name)
  visit card_set_path(card_set, view_type: 'table')
end

When('I visit the grid view for {string} with related sets') do |set_name|
  card_set = CardSet.find_by!(name: set_name)
  visit card_set_path(card_set, view_type: 'grid', include_subsets: true, group_by_set: true)
end

When('I search for {string}') do |query|
  fill_in placeholder: /Search/, with: query
  # Give JavaScript time to filter
  sleep 0.3
end

When('I filter by {string}') do |filter_option|
  filter_select = find('select[data-card-sort-target="filterField"]')
  filter_select.select(filter_option)
  # Give JavaScript time to filter
  sleep 0.3
end

Then('I should see {int} card(s) displayed') do |count|
  # Wait for JS to apply filters, then count visible cards
  sleep 0.2

  # Count cards that are truly visible (Capybara's visible: true respects display:none)
  visible_cards = all('[data-card-sort-target="item"]', visible: true)
  expect(visible_cards.count).to eq(count), "Expected #{count} cards but found #{visible_cards.count}"
end

Then('I should see {string} in the results') do |card_name|
  # Find visible card with this name
  expect(page).to have_css('[data-card-sort-target="item"]', text: card_name, visible: true)
end

Then('I should not see {string} in the results') do |card_name|
  # Wait for JS to apply filters
  sleep 0.2

  # The card should not be visible (either doesn't exist or has display:none on it or parent)
  # Capybara's visible: true will only find elements that are actually visible
  expect(page).not_to have_css('[data-card-sort-target="item"]', text: card_name, visible: true)
end

Given('a card set {string} with code {string} exists as child of {string}') do |name, code, parent_name|
  parent = CardSet.find_by!(name: parent_name)
  @related_set = create(:card_set, name: name, code: code, card_count: 0, download_status: :completed, parent_set_code: parent.code)
end

Given('the {string} has the following cards:') do |set_name, table|
  card_set = CardSet.find_by!(name: set_name)
  table.hashes.each do |row|
    create(:card,
      card_set: card_set,
      name: row['name'],
      collector_number: row['collector_number'],
      rarity: row['rarity'] || 'common'
    )
  end
  card_set.update(card_count: card_set.cards.count)
end
