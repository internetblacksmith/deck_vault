# Sidekiq Background Jobs Setup

This document explains how to set up and run Sidekiq for background image downloading in the MTG Collection Manager.

## What is Sidekiq?

Sidekiq is a Ruby background job processor that uses Redis as a message queue. It allows long-running tasks (like downloading 265 card images) to run in the background without blocking HTTP requests.

## Installation

The Sidekiq and Redis gems are already added to the Gemfile:

```ruby
gem "sidekiq", "~> 7.0"
gem "redis", "~> 5.0"
```

Install them with:

```bash
bundle install
```

## Redis Setup

Sidekiq requires Redis to be running. Redis can be installed via:

### macOS
```bash
brew install redis
brew services start redis
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install redis-server
sudo systemctl start redis-server
```

### Docker
```bash
docker run -d -p 6379:6379 redis:latest
```

### Verify Redis is running
```bash
redis-cli ping
# Should return: PONG
```

## Running in Development

### Terminal 1: Rails Server
```bash
bin/rails server
```

### Terminal 2: Sidekiq Worker
```bash
bundle exec sidekiq -c 5 -v
```

The `-c 5` flag sets concurrency to 5 (5 images downloading in parallel)
The `-v` flag enables verbose logging

### Terminal 3 (Optional): Redis Monitor
```bash
redis-cli
> MONITOR
```

This shows Redis commands as they happen (useful for debugging)

## How It Works

### When You Download a Set

1. User clicks "Download" in the web interface
2. `CardSetsController#download_set` is called
3. Set data is fetched and saved immediately
4. For each card, `DownloadCardImagesJob` is queued (not executed yet)
5. HTTP response is sent to user immediately
6. Sidekiq worker processes queued jobs in the background
7. Progress is visible in the UI with auto-refresh

### Job Flow

```
User clicks Download
    ↓
Set data fetched and saved
    ↓
DownloadCardImagesJob queued for each card (in Redis)
    ↓
HTTP response sent to user (fast!)
    ↓
Sidekiq worker picks up jobs from Redis
    ↓
Images downloaded and saved
    ↓
CardSet progress updated
    ↓
UI auto-refreshes showing progress
    ↓
Completion detected, page shows "✓ All images downloaded"
```

## Configuration Files

### config/sidekiq.yml
Defines Sidekiq queues and concurrency settings:
- `critical`: High priority jobs
- `default`: Regular jobs (image downloading)
- `mailers`: Email jobs
- `low`: Low priority jobs

### config/environments/development.rb
```ruby
config.active_job.queue_adapter = :sidekiq
```

### config/environments/production.rb
```ruby
config.active_job.queue_adapter = :sidekiq
```

## Job Retry Logic

The `DownloadCardImagesJob` has retry logic configured:

```ruby
sidekiq_options retry: 3
```

If an image download fails, it will retry up to 3 times before giving up.

## Monitoring

### View Pending Jobs
```bash
redis-cli
> LLEN "queue:default"  # Number of pending jobs
> LLEN "queue:critical" # Number of critical jobs
```

### Clear All Jobs (Development Only)
```bash
redis-cli FLUSHDB
```

### Web UI (Optional)

You can add Sidekiq Web for a visual dashboard:

1. Add to Gemfile:
   ```ruby
   gem "sidekiq-web"
   ```

2. Add to routes.rb:
   ```ruby
   require 'sidekiq/web'
   mount Sidekiq::Web => '/sidekiq'
   ```

3. Access at: http://localhost:3000/sidekiq

## Performance

### Download Speed
- Sequential (old way): ~90 seconds for 265 cards
- Parallel with Sidekiq: ~20-30 seconds (concurrency: 5)

### Why the improvement?
- Old: Download image 1, wait for response, download image 2, wait...
- New: Queue 265 jobs instantly, Sidekiq downloads 5 in parallel

### Configuring Concurrency
Edit `config/sidekiq.yml`:

```yaml
development:
  :max_concurrency: 5   # Lower = fewer simultaneous downloads
  
production:
  :max_concurrency: 25  # Higher = more downloads in parallel
```

## Troubleshooting

### "Redis connection refused"
- Make sure Redis is running: `redis-cli ping`
- Check connection: `bundle exec sidekiq -v` (in separate terminal)

### Jobs not processing
- Check if Sidekiq worker is running: `ps aux | grep sidekiq`
- Check Redis has jobs: `redis-cli LLEN "queue:default"`
- Check Sidekiq logs for errors

### Progress not updating
- Make sure you're running Sidekiq: `bundle exec sidekiq`
- Check browser console for JavaScript errors
- Verify Redis is connected: `redis-cli INFO stats`

### Reset Everything (Development)
```bash
# Stop Sidekiq and Rails servers first

# Clear Redis
redis-cli FLUSHDB

# Reset database
bin/rails db:drop db:create db:migrate

# Start fresh
bin/rails server
bundle exec sidekiq -c 5 -v
```

## Production Deployment

For production, use a process manager:

### Using Systemd (Linux)
Create `/etc/systemd/system/sidekiq.service`:

```ini
[Unit]
Description=Sidekiq
After=syslog.target network.target

[Service]
Type=simple
WorkingDirectory=/path/to/mtg_collector
ExecStart=/usr/bin/bundle exec sidekiq -e production -c 25
Restart=always
StandardOutput=append:/var/log/sidekiq.log
StandardError=append:/var/log/sidekiq.log

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable sidekiq
sudo systemctl start sidekiq
```

### Using Docker
See `Dockerfile` for containerized setup.

## Best Practices

1. **Always run Sidekiq in development** - Otherwise jobs won't process
2. **Monitor Redis memory** - Use `redis-cli INFO` to check usage
3. **Set appropriate concurrency** - Balance between speed and resource usage
4. **Use queue priorities** - Critical jobs should use `:critical` queue
5. **Log job progress** - Sidekiq logs all job execution
6. **Test with real data** - Test downloads with actual card sets

## Performance Monitoring

### Watch Sidekiq in real-time
```bash
watch -n 1 'redis-cli LLEN queue:default'
```

### Check processing stats
```bash
redis-cli
> INFO stats
```

## Further Reading

- [Sidekiq Documentation](https://github.com/sidekiq/sidekiq/wiki)
- [Redis Documentation](https://redis.io/docs/)
- [Rails Active Job Guide](https://guides.rubyonrails.org/active_job_basics.html)
