Feature: Delver Lens CSV Import
  As a collector
  I want to import my cards from Delver Lens CSV exports
  So that I can quickly add scanned cards to my collection

  Background:
    Given I am logged in

  @javascript
  Scenario: Import Delver panel toggles open and closed
    When I visit the collection index page
    Then I should see the "Import Delver" button
    When I click "Import Delver"
    Then I should see the Delver import panel
    And I should see the "Add to collection" option selected
    When I click "Cancel"
    Then I should not see the Delver import panel

  @javascript
  Scenario: Import Delver CSV in add mode
    Given a card set "Avatar: The Last Airbender" with code "tla" exists
    And the set has the following cards:
      | name                  | collector_number |
      | Aang, Avatar State    | 1                |
      | Katara, Waterbender   | 2                |
    And I have a Delver CSV file with:
      | name                  | edition_code | collector_number | quantity | foil | scryfall_id |
      | Aang, Avatar State    | TLA          | 1                | 2x       |      | card-1      |
    When I visit the collection index page
    And I click "Import Delver"
    And I attach the Delver CSV file
    And I click "Import from Delver"
    Then I should see "Added 2 cards"
    And "Aang, Avatar State" should have quantity 2

  @javascript
  Scenario: Import Delver CSV in replace mode
    Given a card set "Avatar: The Last Airbender" with code "tla" exists
    And the set has the following cards:
      | name                  | collector_number |
      | Aang, Avatar State    | 1                |
    And I own 5 copies of "Aang, Avatar State"
    And I have a Delver CSV file with:
      | name                  | edition_code | collector_number | quantity | foil | scryfall_id |
      | Aang, Avatar State    | TLA          | 1                | 2x       |      | card-1      |
    When I visit the collection index page
    And I click "Import Delver"
    And I attach the Delver CSV file
    And I select "Replace collection"
    And I click "Import from Delver"
    Then I should see "Replaced with 2 cards"
    And "Aang, Avatar State" should have quantity 2

  @javascript
  Scenario: Auto-download missing sets from Scryfall
    Given Scryfall will provide set "soi" with name "Shadows over Innistrad"
    And I have a Delver CSV file for missing set:
      | name                  | edition_code | collector_number | quantity | foil | scryfall_id        |
      | Archangel Avacyn      | SOI          | 5                | 1x       |      | archangel-avacyn-1 |
    When I visit the collection index page
    And I click "Import Delver"
    And I attach the Delver CSV file
    And I click "Import from Delver"
    Then I should see "Downloaded 1 set(s)"
    And I should see "Shadows over Innistrad"
