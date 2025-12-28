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
end
