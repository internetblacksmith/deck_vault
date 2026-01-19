# frozen_string_literal: true

# Simple in-memory rate limiting for login attempts
# Suitable for single-instance local applications
module RateLimitable
  extend ActiveSupport::Concern

  # In-memory store for tracking attempts
  # Format: { "ip_address" => { count: n, reset_at: timestamp } }
  ATTEMPT_STORE = {}
  ATTEMPT_MUTEX = Mutex.new

  # Configuration
  MAX_ATTEMPTS = 5
  LOCKOUT_DURATION = 15.minutes

  class_methods do
    def rate_limit(options = {})
      max_attempts = options[:max_attempts] || MAX_ATTEMPTS
      lockout_duration = options[:lockout_duration] || LOCKOUT_DURATION

      before_action(options.slice(:only, :except)) do
        check_rate_limit(max_attempts, lockout_duration)
      end
    end

    # Reset all rate limit records (for testing)
    def reset_rate_limits!
      ATTEMPT_MUTEX.synchronize do
        ATTEMPT_STORE.clear
      end
    end
  end

  private

  def check_rate_limit(max_attempts, lockout_duration)
    # Skip rate limiting in test environment
    return if Rails.env.test?

    client_ip = request.remote_ip

    ATTEMPT_MUTEX.synchronize do
      cleanup_expired_entries
      record = ATTEMPT_STORE[client_ip]

      if record && record[:count] >= max_attempts && Time.current < record[:reset_at]
        remaining = ((record[:reset_at] - Time.current) / 60).ceil
        respond_to do |format|
          format.html do
            flash[:alert] = "Too many login attempts. Please try again in #{remaining} minutes."
            redirect_to login_path
          end
          format.json { render json: { error: "Rate limited", retry_after: remaining }, status: :too_many_requests }
        end
        return
      end
    end
  end

  def record_failed_attempt
    # Skip rate limiting in test environment
    return if Rails.env.test?

    client_ip = request.remote_ip

    ATTEMPT_MUTEX.synchronize do
      record = ATTEMPT_STORE[client_ip] ||= { count: 0, reset_at: Time.current + LOCKOUT_DURATION }

      # Reset if lockout expired
      if Time.current >= record[:reset_at]
        record[:count] = 0
        record[:reset_at] = Time.current + LOCKOUT_DURATION
      end

      record[:count] += 1
    end
  end

  def reset_attempts
    # Skip rate limiting in test environment
    return if Rails.env.test?

    client_ip = request.remote_ip

    ATTEMPT_MUTEX.synchronize do
      ATTEMPT_STORE.delete(client_ip)
    end
  end

  def cleanup_expired_entries
    now = Time.current
    ATTEMPT_STORE.delete_if { |_ip, record| now >= record[:reset_at] }
  end
end
