/**
 * Import collection data and download card images
 * 
 * Usage:
 *   npm run import -- --input path/to/collection.json
 *   npm run import -- --url http://localhost:3000/card_sets/export_showcase
 */

import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import * as http from 'http';

interface Card {
  id: string;
  name: string;
  image_url: string | null;
  back_image_url: string | null;
}

interface CollectionData {
  version: number;
  cards: Card[];
  [key: string]: unknown;
}

const IMAGES_DIR = path.join(process.cwd(), 'public', 'images');
const DATA_FILE = path.join(process.cwd(), 'src', 'data', 'collection.json');

// Rate limiting for Scryfall (100ms between requests)
const RATE_LIMIT_MS = 100;

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function downloadFile(url: string, dest: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    const protocol = url.startsWith('https') ? https : http;
    
    protocol.get(url, (response) => {
      if (response.statusCode === 301 || response.statusCode === 302) {
        // Follow redirect
        const redirectUrl = response.headers.location;
        if (redirectUrl) {
          file.close();
          fs.unlinkSync(dest);
          downloadFile(redirectUrl, dest).then(resolve).catch(reject);
          return;
        }
      }
      
      if (response.statusCode !== 200) {
        file.close();
        fs.unlinkSync(dest);
        reject(new Error(`Failed to download: ${response.statusCode}`));
        return;
      }
      
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      file.close();
      fs.unlink(dest, () => {}); // Delete partial file
      reject(err);
    });
  });
}

async function downloadImages(cards: Card[]): Promise<{ downloaded: number; skipped: number; failed: number }> {
  // Ensure images directory exists
  if (!fs.existsSync(IMAGES_DIR)) {
    fs.mkdirSync(IMAGES_DIR, { recursive: true });
  }

  let downloaded = 0;
  let skipped = 0;
  let failed = 0;

  console.log(`\nDownloading images for ${cards.length} cards...`);

  for (let i = 0; i < cards.length; i++) {
    const card = cards[i];
    const progress = `[${i + 1}/${cards.length}]`;

    // Download front image
    if (card.image_url) {
      const imagePath = path.join(IMAGES_DIR, `${card.id}.jpg`);
      
      if (fs.existsSync(imagePath)) {
        skipped++;
      } else {
        try {
          process.stdout.write(`${progress} Downloading ${card.name}...`);
          await downloadFile(card.image_url, imagePath);
          downloaded++;
          console.log(' OK');
          await sleep(RATE_LIMIT_MS);
        } catch (error) {
          failed++;
          console.log(` FAILED: ${error}`);
        }
      }
    }

    // Download back image for DFCs
    if (card.back_image_url) {
      const backImagePath = path.join(IMAGES_DIR, `${card.id}_back.jpg`);
      
      if (!fs.existsSync(backImagePath)) {
        try {
          process.stdout.write(`${progress} Downloading ${card.name} (back)...`);
          await downloadFile(card.back_image_url, backImagePath);
          downloaded++;
          console.log(' OK');
          await sleep(RATE_LIMIT_MS);
        } catch (error) {
          failed++;
          console.log(` FAILED: ${error}`);
        }
      }
    }
  }

  return { downloaded, skipped, failed };
}

async function fetchFromUrl(url: string): Promise<CollectionData> {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    
    protocol.get(url, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`HTTP ${response.statusCode}`));
        return;
      }
      
      let data = '';
      response.on('data', chunk => data += chunk);
      response.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error('Invalid JSON response'));
        }
      });
    }).on('error', reject);
  });
}

async function main() {
  const args = process.argv.slice(2);
  let inputFile: string | null = null;
  let inputUrl: string | null = null;
  let skipImages = false;

  // Parse arguments
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--input' && args[i + 1]) {
      inputFile = args[++i];
    } else if (args[i] === '--url' && args[i + 1]) {
      inputUrl = args[++i];
    } else if (args[i] === '--skip-images') {
      skipImages = true;
    }
  }

  if (!inputFile && !inputUrl) {
    console.log('Usage:');
    console.log('  npm run import -- --input path/to/collection.json');
    console.log('  npm run import -- --url http://localhost:3000/card_sets/export_showcase');
    console.log('  npm run import -- --input collection.json --skip-images');
    process.exit(1);
  }

  let data: CollectionData;

  // Load data
  if (inputUrl) {
    console.log(`Fetching from ${inputUrl}...`);
    try {
      data = await fetchFromUrl(inputUrl);
      console.log('Fetched successfully!');
    } catch (error) {
      console.error(`Failed to fetch: ${error}`);
      process.exit(1);
    }
  } else if (inputFile) {
    console.log(`Reading from ${inputFile}...`);
    try {
      const content = fs.readFileSync(inputFile, 'utf-8');
      data = JSON.parse(content);
      console.log('Loaded successfully!');
    } catch (error) {
      console.error(`Failed to read file: ${error}`);
      process.exit(1);
    }
  } else {
    process.exit(1);
  }

  // Validate data
  if (data.version !== 2 || !Array.isArray(data.cards)) {
    console.error('Invalid collection data format. Expected version 2 showcase export.');
    process.exit(1);
  }

  console.log(`\nCollection stats:`);
  console.log(`  Cards: ${data.cards.length}`);
  console.log(`  Sets: ${(data as any).sets?.length || 0}`);

  // Save data to src/data/collection.json
  const dataDir = path.dirname(DATA_FILE);
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
  }
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
  console.log(`\nSaved collection data to ${DATA_FILE}`);

  // Download images
  if (!skipImages && data.cards.length > 0) {
    const results = await downloadImages(data.cards);
    console.log(`\nImage download complete:`);
    console.log(`  Downloaded: ${results.downloaded}`);
    console.log(`  Skipped (already exists): ${results.skipped}`);
    console.log(`  Failed: ${results.failed}`);
  } else if (skipImages) {
    console.log('\nSkipping image download (--skip-images)');
  }

  console.log('\nDone! Run `npm run build` to generate the static site.');
}

main().catch(console.error);
