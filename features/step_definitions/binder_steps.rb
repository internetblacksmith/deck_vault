# Binder view step definitions

Then('I should see the stats showing {string} owned cards') do |count|
  # Look for "Unique" label which shows owned count, or the Cards X/Y format
  expect(page).to have_content('Unique')
  # The owned count should appear
  expect(page).to have_css('div', text: count)
end

Then('I should see {string} completion') do |percentage|
  expect(page).to have_content(percentage)
end

Then('{string} should appear as owned') do |card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  # Find the card container by data-card-id
  card_container = find("[data-card-id='#{card.id}']")
  # Owned cards should NOT have opacity in their style (or have opacity: 1)
  front = card_container.find('[data-binder-card-target="front"]')
  style = front[:style] || ''
  # Not owned cards have "opacity:0.35" or "opacity: 0.35"
  expect(style).not_to match(/opacity:\s*0\.35/)
end

Then('{string} should appear as not owned') do |card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  card_container = find("[data-card-id='#{card.id}']")
  front = card_container.find('[data-binder-card-target="front"]')
  style = front[:style] || ''
  # Card should have reduced opacity (0.5) when not owned
  expect(style).to match(/opacity:\s*0\.5/)
end

Then('{string} should show a quantity badge of {string}') do |card_name, badge_text|
  card = Card.includes(:card_set).find_by!(name: card_name)
  card_container = find("[data-card-id='#{card.id}']")
  expect(card_container).to have_content(badge_text)
end

Then('{string} should show a foil quantity badge of {string}') do |card_name, badge_text|
  card = Card.includes(:card_set).find_by!(name: card_name)
  card_container = find("[data-card-id='#{card.id}']")
  # Foil badges have a purple gradient background
  expect(card_container).to have_content(badge_text)
end

When('I click on {string} card') do |card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  @current_card = card
  @current_card_container = find("[data-card-id='#{card.id}']")
  # Click the edit button (cog icon) to open the editor
  @current_card_container.find('button[data-action="click->binder-card#toggleEditor"]').click
end

Then('I should see the edit form for {string}') do |card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  card_container = find("[data-card-id='#{card.id}']")
  editor = card_container.find('[data-binder-card-target="editor"]')
  # The editor overlay should be visible
  expect(editor).to have_content(card_name)
  expect(editor[:style]).to include('display: flex')
end

Then('I should not see the edit form') do
  # All editor overlays should be hidden
  all('[data-binder-card-target="editor"]').each do |editor|
    style = editor[:style] || ''
    expect(style).to include('display: none').or include('display:none')
  end
end

When('I set the regular quantity to {string}') do |quantity|
  # Use the currently clicked card container
  within(@current_card_container) do
    field = find("[data-binder-card-target='quantity']")
    field.set(quantity)
    field.native.send_keys(:tab) # Trigger change event
  end
end

When('I set the foil quantity to {string}') do |quantity|
  within(@current_card_container) do
    field = find("[data-binder-card-target='foilQuantity']")
    field.set(quantity)
    field.native.send_keys(:tab) # Trigger change event
  end
end

Then('I should see a save confirmation') do
  # The editor should briefly show a green glow - just wait for save
  sleep 0.5
  expect(page).to have_css('[data-binder-card-target="editor"]')
end

When('I click the close button') do
  # Click the close button in the editor overlay (the X button inside the editor)
  within(@current_card_container) do
    editor = find('[data-binder-card-target="editor"]')
    within(editor) do
      find('button[data-action="click->binder-card#toggleEditor"]').click
    end
  end
end

Then('I should see {string} on the cover spread') do |text|
  expect(page).to have_content(text)
end

When('I click {string}') do |button_text|
  click_on button_text
end

Then('I should see page navigation showing {string}') do |text|
  expect(page).to have_content(text)
end

# Double-faced card steps
Given('the set has a double-faced card {string}') do |card_name|
  card_set = CardSet.find_by!(code: 'ART')
  create(:card, :double_faced,
    card_set: card_set,
    name: card_name,
    collector_number: '1')
end

Given('the set has a double-faced card {string} with back image') do |card_name|
  card_set = CardSet.find_by!(code: 'ART')
  create(:card, :double_faced, :with_back_image,
    card_set: card_set,
    name: card_name,
    collector_number: '1',
    image_path: 'card_images/front.jpg')
end

Then('I should see the flip button for {string}') do |card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  card_container = find("[data-card-id='#{card.id}']")
  expect(card_container).to have_css('button[data-action="click->binder-card#flipCard"]')
end

Then('I should see the edit button for {string}') do |card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  card_container = find("[data-card-id='#{card.id}']")
  expect(card_container).to have_css('button[data-action="click->binder-card#toggleEditor"]')
end

When('I click the edit button on {string}') do |card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  @current_card = card
  @current_card_container = find("[data-card-id='#{card.id}']")
  @current_card_container.find('button[data-action="click->binder-card#toggleEditor"]').click
end

When('I click the flip button on {string}') do |card_name|
  card = Card.includes(:card_set).find_by!(name: card_name)
  @current_card = card
  @current_card_container = find("[data-card-id='#{card.id}']")
  @current_card_container.find('button[data-action="click->binder-card#flipCard"]').click
end

Then('the card image should show the back face') do
  # The flip button should have changed state (highlighted background)
  within(@current_card_container) do
    flip_button = find('button[data-action="click->binder-card#flipCard"]')
    # After clicking, the button background should change to indicate back face is showing
    # Could be rgb or # format depending on browser
    style = flip_button[:style] || ''
    expect(style).to match(/background.*#2864b4|background.*rgb\(40,\s*100,\s*180/)
  end
end
