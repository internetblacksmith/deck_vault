namespace :scryfall do
  desc "Download a Magic set by set code (e.g., rake scryfall:download_set[tla])"
  task :download_set, [ :set_code ] => :environment do |t, args|
    set_code = args.set_code

    if set_code.blank?
      puts "Usage: rake scryfall:download_set[SET_CODE]"
      puts "Example: rake scryfall:download_set[tla]"
      exit 1
    end

    puts "Downloading set #{set_code}..."
    card_set = ScryfallService.download_set(set_code)

    if card_set
      puts "✓ Successfully downloaded #{card_set.name}"
      puts "  Cards: #{card_set.cards.count}"
      puts "  Released: #{card_set.released_at&.strftime('%B %d, %Y') || 'N/A'}"
    else
      puts "✗ Failed to download set #{set_code}"
      exit 1
    end
  end

  desc "List all available Magic sets from Scryfall"
  task list_sets: :environment do
    puts "Fetching available sets from Scryfall..."
    sets = ScryfallService.fetch_sets

    if sets.empty?
      puts "No sets found or error occurred"
      exit 1
    end

    puts "\nAvailable Magic: The Gathering Sets:"
    puts "-" * 60

    sets.each do |set|
      downloaded = CardSet.find_by(code: set[:code]) ? "✓" : "✗"
      puts "#{downloaded} #{set[:code].upcase.ljust(8)} #{set[:name].ljust(40)} (#{set[:card_count]} cards)"
    end

    puts "-" * 60
    puts "✓ = Already downloaded"
    puts "✗ = Not yet downloaded"
  end

  desc "Show download progress for a set"
  task :set_status, [ :set_code ] => :environment do |t, args|
    set_code = args.set_code

    if set_code.blank?
      puts "Usage: rake scryfall:set_status[SET_CODE]"
      exit 1
    end

    card_set = CardSet.find_by(code: set_code)

    if card_set.nil?
      puts "Set #{set_code} not found in database"
      exit 1
    end

    owned_count = card_set.cards.joins(:collection_card).count
    total_count = card_set.cards.count
    completion = (total_count > 0) ? (owned_count.to_f / total_count * 100).round(2) : 0

    puts "\n#{card_set.name} (#{card_set.code.upcase})"
    puts "=" * 50
    puts "Total Cards:     #{total_count}"
    puts "Owned Cards:     #{owned_count}"
    puts "Completion:      #{completion}%"
    puts "Progress:        #{('█' * (completion / 5).to_i).ljust(20)} #{completion}%"
    puts "=" * 50
  end

  desc "Download all missing card images"
  task download_missing_images: :environment do
    # Find all cards missing front images
    cards_missing_front = Card.where(image_path: nil).where.not(image_uris: nil)
    # Find all double-faced cards missing back images
    cards_missing_back = Card.where(back_image_path: nil).where.not(back_image_uris: nil)

    front_count = cards_missing_front.count
    back_count = cards_missing_back.count
    total_missing = front_count + back_count

    if total_missing.zero?
      puts "✓ All card images are already downloaded!"
      exit 0
    end

    puts "Found #{total_missing} missing images:"
    puts "  - #{front_count} front images"
    puts "  - #{back_count} back images"
    puts ""

    downloaded = 0
    failed = 0
    start_time = Time.now

    # Download missing front images
    if front_count > 0
      puts "Downloading front images..."
      cards_missing_front.includes(:card_set).find_each.with_index do |card, index|
        print "\r  [#{index + 1}/#{front_count}] Downloading #{card.name.truncate(40)}...".ljust(70)

        image_path = ScryfallService.download_card_image(card.to_image_hash)
        if image_path
          card.update(image_path: image_path)
          downloaded += 1
        else
          failed += 1
        end

        # Rate limiting to respect Scryfall API
        sleep(0.05)
      end
      puts "\r  ✓ Front images complete".ljust(70)
    end

    # Download missing back images
    if back_count > 0
      puts "Downloading back images..."
      cards_missing_back.includes(:card_set).find_each.with_index do |card, index|
        print "\r  [#{index + 1}/#{back_count}] Downloading #{card.name.truncate(40)} (back)...".ljust(70)

        back_image_path = ScryfallService.download_card_image(card.to_back_image_hash, suffix: "_back")
        if back_image_path
          card.update(back_image_path: back_image_path)
          downloaded += 1
        else
          failed += 1
        end

        # Rate limiting to respect Scryfall API
        sleep(0.05)
      end
      puts "\r  ✓ Back images complete".ljust(70)
    end

    # Update card set progress counters
    puts "\nUpdating set progress..."
    CardSet.find_each do |card_set|
      images_count = card_set.cards.where.not(image_path: nil).count
      new_status = images_count >= card_set.card_count ? :completed : card_set.download_status
      card_set.update(images_downloaded: images_count, download_status: new_status)
    end

    elapsed = Time.now - start_time
    puts ""
    puts "=" * 50
    puts "Download Complete!"
    puts "  Downloaded: #{downloaded}"
    puts "  Failed:     #{failed}"
    puts "  Time:       #{elapsed.round(1)} seconds"
    puts "=" * 50

    exit 1 if failed > 0
  end

  desc "Download missing images for a specific set"
  task :download_set_images, [ :set_code ] => :environment do |t, args|
    set_code = args.set_code

    if set_code.blank?
      puts "Usage: rake scryfall:download_set_images[SET_CODE]"
      puts "Example: rake scryfall:download_set_images[tla]"
      exit 1
    end

    card_set = CardSet.find_by(code: set_code)

    if card_set.nil?
      puts "✗ Set #{set_code} not found in database"
      puts "Use 'rake scryfall:download_set[#{set_code}]' to download the set first"
      exit 1
    end

    # Find cards in this set missing images
    cards_missing_front = card_set.cards.where(image_path: nil).where.not(image_uris: nil)
    cards_missing_back = card_set.cards.where(back_image_path: nil).where.not(back_image_uris: nil)

    front_count = cards_missing_front.count
    back_count = cards_missing_back.count
    total_missing = front_count + back_count

    if total_missing.zero?
      puts "✓ All images for #{card_set.name} are already downloaded!"
      exit 0
    end

    puts "#{card_set.name} (#{card_set.code.upcase})"
    puts "Found #{total_missing} missing images:"
    puts "  - #{front_count} front images"
    puts "  - #{back_count} back images"
    puts ""

    downloaded = 0
    failed = 0
    start_time = Time.now

    # Download missing front images
    if front_count > 0
      puts "Downloading front images..."
      cards_missing_front.find_each.with_index do |card, index|
        print "\r  [#{index + 1}/#{front_count}] #{card.name.truncate(40)}...".ljust(70)

        image_path = ScryfallService.download_card_image(card.to_image_hash)
        if image_path
          card.update(image_path: image_path)
          downloaded += 1
        else
          failed += 1
        end

        sleep(0.05)
      end
      puts "\r  ✓ Front images complete".ljust(70)
    end

    # Download missing back images
    if back_count > 0
      puts "Downloading back images..."
      cards_missing_back.find_each.with_index do |card, index|
        print "\r  [#{index + 1}/#{back_count}] #{card.name.truncate(40)} (back)...".ljust(70)

        back_image_path = ScryfallService.download_card_image(card.to_back_image_hash, suffix: "_back")
        if back_image_path
          card.update(back_image_path: back_image_path)
          downloaded += 1
        else
          failed += 1
        end

        sleep(0.05)
      end
      puts "\r  ✓ Back images complete".ljust(70)
    end

    # Update card set progress
    images_count = card_set.cards.where.not(image_path: nil).count
    new_status = images_count >= card_set.card_count ? :completed : card_set.download_status
    card_set.update(images_downloaded: images_count, download_status: new_status)

    elapsed = Time.now - start_time
    puts ""
    puts "=" * 50
    puts "Download Complete for #{card_set.name}!"
    puts "  Downloaded: #{downloaded}"
    puts "  Failed:     #{failed}"
    puts "  Time:       #{elapsed.round(1)} seconds"
    puts "  Progress:   #{card_set.reload.download_progress_percentage}%"
    puts "=" * 50

    exit 1 if failed > 0
  end
end
