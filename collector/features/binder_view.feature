Feature: Binder View
  As a collector
  I want to view my cards in a binder layout
  So that I can see my collection organized like a physical binder

  Background:
    Given I am logged in
    And a card set "Test Set" with code "TST" exists
    And the set has the following cards:
      | name          | collector_number |
      | Fire Dragon   | 1                |
      | Water Serpent | 2                |
      | Earth Golem   | 3                |
      | Air Elemental | 4                |

  @javascript
  Scenario: Viewing the binder with owned cards
    Given I own 2 copies of "Fire Dragon"
    And I own 1 foil copies of "Water Serpent"
    When I visit the binder view for "Test Set"
    Then I should see the stats showing "2" owned cards
    And "Fire Dragon" should appear as owned
    And "Water Serpent" should appear as owned
    And "Earth Golem" should appear as not owned
    And "Air Elemental" should appear as not owned

  @javascript
  Scenario: Viewing quantity badges on owned cards
    Given I own 3 copies of "Fire Dragon"
    And I own 2 foil copies of "Fire Dragon"
    When I visit the binder view for "Test Set"
    Then "Fire Dragon" should show a quantity badge of "x3"
    And "Fire Dragon" should show a foil quantity badge of "x2"

  @javascript
  Scenario: Editing card quantities in binder view
    When I visit the binder view for "Test Set"
    And I click on "Fire Dragon" card
    Then I should see the edit form for "Fire Dragon"
    When I set the regular quantity to "2"
    Then I should see a save confirmation
    And "Fire Dragon" should appear as owned

  @javascript
  Scenario: Closing the edit form with close button
    When I visit the binder view for "Test Set"
    And I click on "Fire Dragon" card
    Then I should see the edit form for "Fire Dragon"
    When I click the close button
    Then I should not see the edit form

  @javascript
  Scenario: Navigating binder pages
    Given the binder is configured for 2 rows and 2 columns
    When I visit the binder view for "Test Set"
    Then I should see "Page 1" on the cover spread
    When I click "Next"
    Then I should see page navigation showing "Pages 2-3"

  @javascript
  Scenario: Binder stats reflect collection accurately
    Given I own 2 copies of "Fire Dragon"
    And I own 1 copies of "Water Serpent"
    And I own 0 copies of "Earth Golem"
    When I visit the binder view for "Test Set"
    Then I should see the stats showing "2" owned cards
    And I should see "50.0%" completion

  @javascript
  Scenario: Viewing a double-faced card
    Given a card set "Art Set" with code "ART" exists
    And the set has a double-faced card "Aang // Avatar Aang"
    When I visit the binder view for "Art Set"
    Then I should see the flip button for "Aang // Avatar Aang"
    And I should see the edit button for "Aang // Avatar Aang"

  @javascript
  Scenario: Using the edit button to open quantity editor
    When I visit the binder view for "Test Set"
    And I click the edit button on "Fire Dragon"
    Then I should see the edit form for "Fire Dragon"
    When I set the regular quantity to "1"
    Then I should see a save confirmation

  @javascript
  Scenario: Flipping a double-faced card
    Given a card set "Art Set" with code "ART" exists
    And the set has a double-faced card "Aang // Avatar Aang" with back image
    When I visit the binder view for "Art Set"
    And I click the flip button on "Aang // Avatar Aang"
    Then the card image should show the back face
