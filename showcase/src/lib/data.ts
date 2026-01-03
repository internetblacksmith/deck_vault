// Data loading utilities
import type { ShowcaseData, Card, CardSet, BinderPage, BinderSpread } from './types';

// Load collection data from JSON file
export async function loadCollectionData(): Promise<ShowcaseData> {
  try {
    // In production, this file is generated at build time
    const data = await import('../data/collection.json');
    return data.default as ShowcaseData;
  } catch (error) {
    console.error('Failed to load collection data:', error);
    // Return empty data structure
    return {
      version: 2,
      export_type: 'showcase',
      exported_at: new Date().toISOString(),
      stats: {
        total_unique: 0,
        total_cards: 0,
        total_foils: 0,
        sets_collected: 0,
      },
      sets: [],
      cards: [],
    };
  }
}

// Get cards for a specific set
export function getCardsForSet(cards: Card[], setCode: string): Card[] {
  return cards
    .filter(card => card.set_code.toLowerCase() === setCode.toLowerCase())
    .sort((a, b) => {
      // Sort by collector number (handle numeric and alphanumeric)
      const aNum = parseInt(a.collector_number, 10);
      const bNum = parseInt(b.collector_number, 10);
      if (!isNaN(aNum) && !isNaN(bNum)) {
        return aNum - bNum;
      }
      return a.collector_number.localeCompare(b.collector_number);
    });
}

// Get set by code
export function getSetByCode(sets: CardSet[], code: string): CardSet | undefined {
  return sets.find(set => set.code.toLowerCase() === code.toLowerCase());
}

// Organize cards into binder pages
export function organizeIntoPages(
  cards: Card[],
  cardsPerPage: number = 9,
  sortField: 'number' | 'name' | 'rarity' = 'number'
): BinderPage[] {
  // Sort cards
  const sortedCards = [...cards].sort((a, b) => {
    switch (sortField) {
      case 'name':
        return a.name.localeCompare(b.name);
      case 'rarity': {
        const rarityOrder = { mythic: 0, rare: 1, uncommon: 2, common: 3 };
        const aOrder = rarityOrder[a.rarity as keyof typeof rarityOrder] ?? 4;
        const bOrder = rarityOrder[b.rarity as keyof typeof rarityOrder] ?? 4;
        return aOrder - bOrder || a.name.localeCompare(b.name);
      }
      case 'number':
      default: {
        const aNum = parseInt(a.collector_number, 10);
        const bNum = parseInt(b.collector_number, 10);
        if (!isNaN(aNum) && !isNaN(bNum)) return aNum - bNum;
        return a.collector_number.localeCompare(b.collector_number);
      }
    }
  });

  const pages: BinderPage[] = [];
  let pageNumber = 1;

  for (let i = 0; i < sortedCards.length; i += cardsPerPage) {
    const pageCards = sortedCards.slice(i, i + cardsPerPage);
    // Pad with nulls if needed
    while (pageCards.length < cardsPerPage) {
      pageCards.push(null as unknown as Card);
    }
    pages.push({
      page_number: pageNumber++,
      cards: pageCards,
    });
  }

  return pages;
}

// Organize pages into spreads (left + right pages)
export function organizeIntoSpreads(pages: BinderPage[]): BinderSpread[] {
  const spreads: BinderSpread[] = [];

  // First spread: cover (null) + page 1
  if (pages.length > 0) {
    spreads.push({
      left: null,
      right: pages[0],
    });
  }

  // Remaining spreads: pairs of pages
  for (let i = 1; i < pages.length; i += 2) {
    spreads.push({
      left: pages[i],
      right: pages[i + 1] || null,
    });
  }

  return spreads;
}

// Get rarity color
export function getRarityColor(rarity: string): string {
  switch (rarity?.toLowerCase()) {
    case 'mythic':
      return '#f84';
    case 'rare':
      return '#fc0';
    case 'uncommon':
      return '#aaa';
    case 'common':
    default:
      return '#666';
  }
}

// Format collector number with leading zeros
export function formatCollectorNumber(number: string, setCode?: string): string {
  const num = parseInt(number, 10);
  if (!isNaN(num) && num < 1000) {
    return num.toString().padStart(3, '0');
  }
  return number;
}

// Get local image path (for build-time downloaded images)
export function getLocalImagePath(card: Card): string {
  // During build, images are downloaded to public/images/
  return `/images/${card.id}.jpg`;
}

// Get image URL (fallback to Scryfall if local not available)
export function getImageUrl(card: Card, preferLocal: boolean = true): string {
  if (preferLocal) {
    return getLocalImagePath(card);
  }
  return card.image_url || card.image_url_small || '/placeholder.webp';
}
