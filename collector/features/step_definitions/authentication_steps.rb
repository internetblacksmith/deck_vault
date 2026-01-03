# Authentication step definitions

Given('I am logged in') do
  @current_user = create(:user)
  visit login_path
  fill_in 'username', with: @current_user.username
  fill_in 'password', with: 'SecurePassword123!'
  click_button 'Sign in'
  expect(page).to have_content('Logged in successfully')
end

Given('I am not logged in') do
  # Just ensure we're not logged in by visiting logout
  visit logout_path rescue nil
end
