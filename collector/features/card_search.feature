Feature: Card Search and Filter
  As a collector
  I want to search and filter my cards
  So that I can quickly find specific cards in my collection

  Background:
    Given I am logged in
    And a card set "Number Set" with code "NUM" exists
    And the set has the following cards:
      | name            | collector_number |
      | Card Twenty     | 20               |
      | Card TwentyOne  | 21               |
      | Card TwentyTwo  | 22               |
      | Card OneTwenty  | 120              |
      | Card TwoTwenty  | 220              |
      | Card TwoTwoOne  | 221              |
      | Card TwoTwoNine | 229              |
      | Card ThreeHund  | 300              |

  @javascript
  Scenario: Search with single character wildcard matches exact count
    When I visit the grid view for "Number Set"
    And I search for "22?"
    Then I should see 3 cards displayed
    And I should see "Card TwoTwenty" in the results
    And I should see "Card TwoTwoOne" in the results
    And I should see "Card TwoTwoNine" in the results
    And I should not see "Card TwentyTwo" in the results

  @javascript
  Scenario: Search with multi-character wildcard
    When I visit the grid view for "Number Set"
    And I search for "22*"
    Then I should see 4 cards displayed
    And I should see "Card TwentyTwo" in the results
    And I should see "Card TwoTwenty" in the results
    And I should see "Card TwoTwoOne" in the results
    And I should not see "Card OneTwenty" in the results

  @javascript
  Scenario: Search with leading wildcard matches anywhere
    When I visit the grid view for "Number Set"
    And I search for "*20"
    Then I should see 3 cards displayed
    And I should see "Card Twenty" in the results
    And I should see "Card OneTwenty" in the results
    And I should see "Card TwoTwenty" in the results

  @javascript
  Scenario: Search without wildcard matches anywhere
    When I visit the grid view for "Number Set"
    And I search for "22"
    Then I should see 4 cards displayed
    And I should see "Card TwentyTwo" in the results
    And I should see "Card TwoTwenty" in the results
    And I should see "Card TwoTwoOne" in the results
    And I should see "Card TwoTwoNine" in the results

  @javascript
  Scenario: Search by card name
    When I visit the grid view for "Number Set"
    And I search for "threehund"
    Then I should see 1 card displayed
    And I should see "Card ThreeHund" in the results

  @javascript
  Scenario: Filter shows only owned cards
    Given I own 1 copies of "Card Twenty"
    And I own 1 copies of "Card TwoTwenty"
    When I visit the grid view for "Number Set"
    And I filter by "Owned"
    Then I should see 2 cards displayed
    And I should see "Card Twenty" in the results
    And I should see "Card TwoTwenty" in the results

  @javascript
  Scenario: Filter shows only missing cards
    Given I own 1 copies of "Card ThreeHund"
    When I visit the grid view for "Number Set"
    And I filter by "Missing"
    Then I should see 7 cards displayed
    And I should not see "Card ThreeHund" in the results

  @javascript
  Scenario: Search and filter work together
    Given I own 1 copies of "Card TwoTwenty"
    Given I own 1 copies of "Card TwoTwoOne"
    When I visit the grid view for "Number Set"
    And I search for "22?"
    And I filter by "Owned"
    Then I should see 2 cards displayed
    And I should see "Card TwoTwenty" in the results
    And I should see "Card TwoTwoOne" in the results
    And I should not see "Card TwoTwoNine" in the results

  @javascript
  Scenario: Search works in table view
    When I visit the table view for "Number Set"
    And I search for "22?"
    Then I should see 3 cards displayed
    And I should see "Card TwoTwenty" in the results

  @javascript
  Scenario: Search works with related sets
    Given a card set "Related Set" with code "REL" exists as child of "Number Set"
    And the "Related Set" has the following cards:
      | name            | collector_number |
      | Related TwoTwo  | 225              |
      | Related Three   | 300              |
    When I visit the grid view for "Number Set" with related sets
    And I search for "22?"
    Then I should see 4 cards displayed
    And I should see "Card TwoTwenty" in the results
    And I should see "Related TwoTwo" in the results
