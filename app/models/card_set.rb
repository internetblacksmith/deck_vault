class CardSet < ApplicationRecord
  has_many :cards, dependent: :destroy
  validates :code, :name, presence: true
  validates :code, uniqueness: true
end
