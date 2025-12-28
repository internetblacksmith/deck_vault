VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.default_cassette_options = { record: :once }

  # Filter sensitive data
  config.filter_sensitive_data('<SCRYFALL_API>') { 'https://api.scryfall.com' }

  # Allow real connections to localhost for tests that need it
  config.ignore_localhost = true
end

RSpec.configure do |config|
  config.around(:each, :vcr) do |example|
    name = example.metadata[:vcr][:cassette_name] || example.metadata[:full_description].underscore
    VCR.use_cassette(name, record: :once) { example.run }
  end
end
