# frozen_string_literal: true

class SessionsController < ApplicationController
  include RateLimitable

  skip_before_action :authenticate_user, only: [ :new, :create ]
  rate_limit only: :create, max_attempts: 5, lockout_duration: 15.minutes

  def new
    # Show login form
  end

  def create
    user = User.find_by(username: params[:username])

    if user&.authenticate(params[:password])
      reset_attempts
      session[:user_id] = user.id
      redirect_to root_path, notice: "Logged in successfully"
    else
      record_failed_attempt
      redirect_to login_path, alert: "Invalid username or password"
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: "Logged out successfully"
  end
end
