# Authentication helpers for Cucumber tests

module AuthenticationHelpers
  def login_user(user = nil)
    user ||= create(:user)
    visit login_path
    fill_in 'Username', with: user.username
    fill_in 'Password', with: 'SecurePassword123!'
    click_button 'Login'
    user
  end

  def current_user
    @current_user
  end
end

World(AuthenticationHelpers)
