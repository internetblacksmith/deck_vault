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
  Scenario: Preview without file shows error
    When I visit the collection index page
    And I click "Import Delver"
    And I click "Preview Import"
    Then I should see "Please select at least one CSV file"

  @javascript
  Scenario: Preview with invalid file shows error
    Given I have an invalid non-CSV file
    When I visit the collection index page
    And I click "Import Delver"
    And I attach the invalid file
    And I click "Preview Import"
    Then I should see "Invalid file type"

  @javascript
  Scenario: Escape key closes preview modal
    Given a card set "Avatar: The Last Airbender" with code "tla" exists
    And the set has the following cards:
      | name                  | collector_number |
      | Aang, Avatar State    | 1                |
    And I have a Delver CSV file with:
      | name                  | edition_code | collector_number | quantity | foil | scryfall_id |
      | Aang, Avatar State    | TLA          | 1                | 1x       |      | card-1      |
    When I visit the collection index page
    And I click "Import Delver"
    And I attach the Delver CSV file
    And I click "Preview Import"
    Then I should see the import preview modal
    When I press the Escape key
    Then I should not see the import preview modal

  @javascript
  Scenario: Preview import shows modal with card summary
    Given a card set "Avatar: The Last Airbender" with code "tla" exists
    And the set has the following cards:
      | name                  | collector_number |
      | Aang, Avatar State    | 1                |
      | Katara, Waterbender   | 2                |
    And I have a Delver CSV file with:
      | name                  | edition_code | collector_number | quantity | foil | scryfall_id |
      | Aang, Avatar State    | TLA          | 1                | 2x       |      | card-1      |
      | Katara, Waterbender   | TLA          | 2                | 1x       | Foil | card-2      |
    When I visit the collection index page
    And I click "Import Delver"
    And I attach the Delver CSV file
    And I click "Preview Import"
    Then I should see the import preview modal
    And I should see "3" as the total count
    And I should see "2" as the regular count
    And I should see "1" as the foil count
    And I should see "Aang, Avatar State" in the preview
    When I click "Cancel" in the modal
    Then I should not see the import preview modal

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
    And I click "Preview Import"
    Then I should see the import preview modal
    When I confirm the import
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
    And I click "Preview Import"
    Then I should see the import preview modal
    When I confirm the import
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
    And I click "Preview Import"
    Then I should see the import preview modal
    And I should see "SOI" in the missing sets warning
    When I confirm the import
    Then I should see "Downloaded 1 set(s)"
    And I should see "Shadows over Innistrad"

  @javascript
  Scenario: Import marks cards for binder placement in add mode
    Given a card set "Avatar: The Last Airbender" with code "tla" exists
    And the set has the following cards:
      | name                  | collector_number |
      | Aang, Avatar State    | 1                |
    And I have a Delver CSV file with:
      | name                  | edition_code | collector_number | quantity | foil | scryfall_id |
      | Aang, Avatar State    | TLA          | 1                | 2x       |      | card-1      |
    When I visit the collection index page
    And I click "Import Delver"
    And I attach the Delver CSV file
    And I click "Preview Import"
    Then I should see the import preview modal
    When I confirm the import
    Then I should see "Added 2 cards"
    And I should see "2 cards marked NEW for binder placement"
    And "Aang, Avatar State" should need placement

  @javascript
  Scenario: Import does NOT mark cards for placement in replace mode
    Given a card set "Avatar: The Last Airbender" with code "tla" exists
    And the set has the following cards:
      | name                  | collector_number |
      | Aang, Avatar State    | 1                |
    And I have a Delver CSV file with:
      | name                  | edition_code | collector_number | quantity | foil | scryfall_id |
      | Aang, Avatar State    | TLA          | 1                | 2x       |      | card-1      |
    When I visit the collection index page
    And I click "Import Delver"
    And I attach the Delver CSV file
    And I select "Replace collection"
    And I click "Preview Import"
    Then I should see the import preview modal
    When I confirm the import
    Then I should see "Replaced with 2 cards"
    And I should see "Replace mode: Cards were NOT marked for binder placement"
    And "Aang, Avatar State" should not need placement
