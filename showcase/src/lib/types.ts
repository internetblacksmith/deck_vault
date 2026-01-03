// Types for the showcase data

export interface CardSet {
  code: string;
  name: string;
  released_at: string | null;
  card_count: number;
  owned_count: number;
  completion_percentage: number;
}

export interface Card {
  id: string;
  name: string;
  set_code: string;
  set_name: string;
  collector_number: string;
  rarity: string;
  type_line: string | null;
  mana_cost: string | null;
  image_url: string | null;
  image_url_small: string | null;
  back_image_url: string | null;
  is_foil_available: boolean;
  is_nonfoil_available: boolean;
  quantity: number;
  foil_quantity: number;
}

export interface CollectionStats {
  total_unique: number;
  total_cards: number;
  total_foils: number;
  sets_collected: number;
}

export interface ShowcaseData {
  version: number;
  export_type: string;
  exported_at: string;
  stats: CollectionStats;
  sets: CardSet[];
  cards: Card[];
}

// Binder page structure
export interface BinderPage {
  page_number: number;
  cards: (Card | null)[];
}

export interface BinderSpread {
  left: BinderPage | null;
  right: BinderPage | null;
}
