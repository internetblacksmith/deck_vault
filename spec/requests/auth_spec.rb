require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  describe 'GET /login' do
    it 'returns a successful response' do
      get login_path
      expect(response).to be_successful
    end

    it 'returns HTML' do
      get login_path
      expect(response.content_type).to include('text/html')
    end

    it 'displays login form' do
      get login_path
      expect(response.body).to include('Sign in')
    end
  end

  describe 'POST /login' do
    let(:user) { create(:user, email: 'test@example.com', password: 'password123', password_confirmation: 'password123') }

    context 'with valid credentials' do
      it 'creates a session' do
        post login_path, params: { email: user.email, password: 'password123' }
        expect(session[:user_id]).to eq(user.id)
      end

      it 'redirects to home' do
        post login_path, params: { email: user.email, password: 'password123' }
        expect(response).to redirect_to(root_path)
      end

      it 'shows success message' do
        post login_path, params: { email: user.email, password: 'password123' }
        follow_redirect!
        expect(flash[:notice]).to include('Logged in successfully')
      end
    end

    context 'with invalid email' do
      it 'does not create a session' do
        post login_path, params: { email: 'wrong@example.com', password: 'password123' }
        expect(session[:user_id]).to be_nil
      end

      it 'redirects to login' do
        post login_path, params: { email: 'wrong@example.com', password: 'password123' }
        expect(response).to redirect_to(login_path)
      end

      it 'shows error message' do
        post login_path, params: { email: 'wrong@example.com', password: 'password123' }
        follow_redirect!
        expect(flash[:alert]).to include('Invalid email or password')
      end
    end

    context 'with invalid password' do
      it 'does not create a session' do
        post login_path, params: { email: user.email, password: 'wrongpassword' }
        expect(session[:user_id]).to be_nil
      end

      it 'shows error message' do
        post login_path, params: { email: user.email, password: 'wrongpassword' }
        follow_redirect!
        expect(flash[:alert]).to include('Invalid email or password')
      end
    end

    context 'with missing email' do
      it 'does not create a session' do
        post login_path, params: { email: '', password: 'password123' }
        expect(session[:user_id]).to be_nil
      end
    end

    context 'with missing password' do
      it 'does not create a session' do
        post login_path, params: { email: user.email, password: '' }
        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe 'GET /sign_up' do
    it 'returns a successful response' do
      get sign_up_path
      expect(response).to be_successful
    end

    it 'returns HTML' do
      get sign_up_path
      expect(response.content_type).to include('text/html')
    end

    it 'displays signup form' do
      get sign_up_path
      expect(response.body).to include('Create Account')
    end
  end

  describe 'POST /sign_up' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          user: {
            email: 'newuser@example.com',
            password: 'SecurePassword123!',
            password_confirmation: 'SecurePassword123!'
          }
        }
      end

      it 'creates a new user' do
        expect {
          post sign_up_path, params: valid_params
        }.to change(User, :count).by(1)
      end

      it 'creates a session' do
        post sign_up_path, params: valid_params
        expect(session[:user_id]).to be_present
      end

      it 'redirects to home' do
        post sign_up_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end

      it 'shows success message' do
        post sign_up_path, params: valid_params
        follow_redirect!
        expect(flash[:notice]).to include('Account created successfully')
      end

      it 'stores email correctly' do
        post sign_up_path, params: valid_params
        user = User.find_by(email: 'newuser@example.com')
        expect(user).to be_present
        expect(user.authenticate('SecurePassword123!')).to be_truthy
      end
    end

    context 'with invalid email' do
      let(:invalid_params) do
        {
          user: {
            email: 'not-an-email',
            password: 'SecurePassword123!',
            password_confirmation: 'SecurePassword123!'
          }
        }
      end

      it 'does not create a user' do
        expect {
          post sign_up_path, params: invalid_params
        }.not_to change(User, :count)
      end

      it 'returns unprocessable_entity status' do
        post sign_up_path, params: invalid_params
        expect(response).to have_http_status(422)
      end

      it 'shows error messages' do
        post sign_up_path, params: invalid_params
        expect(response.body).to include('error')
      end
    end

    context 'with duplicate email' do
      before do
        create(:user, email: 'existing@example.com')
      end

      let(:duplicate_params) do
        {
          user: {
            email: 'existing@example.com',
            password: 'SecurePassword123!',
            password_confirmation: 'SecurePassword123!'
          }
        }
      end

      it 'does not create a user' do
        initial_count = User.count
        post sign_up_path, params: duplicate_params
        expect(User.count).to eq(initial_count)
      end

      it 'shows error message' do
        post sign_up_path, params: duplicate_params
        expect(response.body).to include('error')
      end
    end

    context 'with password mismatch' do
      let(:mismatch_params) do
        {
          user: {
            email: 'newuser@example.com',
            password: 'SecurePassword123!',
            password_confirmation: 'DifferentPassword123!'
          }
        }
      end

      it 'does not create a user' do
        expect {
          post sign_up_path, params: mismatch_params
        }.not_to change(User, :count)
      end

      it 'shows error message' do
        post sign_up_path, params: mismatch_params
        expect(response.body).to include('error')
      end
    end

    context 'with missing password' do
      let(:no_password_params) do
        {
          user: {
            email: 'newuser@example.com',
            password: '',
            password_confirmation: ''
          }
        }
      end

      it 'does not create a user' do
        expect {
          post sign_up_path, params: no_password_params
        }.not_to change(User, :count)
      end
    end
  end

  describe 'DELETE /logout' do
    let(:user) { create(:user) }

    context 'when user is logged in' do
      before do
        post login_path, params: { email: user.email, password: 'SecurePassword123!' }
      end

      it 'clears the session' do
        delete logout_path
        expect(session[:user_id]).to be_nil
      end

      it 'redirects to login' do
        delete logout_path
        expect(response).to redirect_to(login_path)
      end

      it 'shows success message' do
        delete logout_path
        follow_redirect!
        expect(flash[:notice]).to include('Logged out successfully')
      end
    end
  end

  describe 'Protected routes' do
    let(:user) { create(:user) }

    context 'when not logged in' do
      it 'redirects to login from card_sets#index' do
        get card_sets_path
        expect(response).to redirect_to(login_path)
      end

      it 'shows alert' do
        get card_sets_path
        follow_redirect!
        expect(flash[:alert]).to include('Please log in first')
      end
    end

    context 'when logged in' do
      before do
        post login_path, params: { email: user.email, password: 'SecurePassword123!' }
      end

      it 'allows access to root' do
        get root_path
        expect(response).to be_successful
      end

      it 'does not redirect' do
        get root_path
        expect(response).not_to redirect_to(login_path)
      end
    end
  end

  describe 'Session persistence' do
    let(:user) { create(:user) }

    it 'maintains session across requests' do
      post login_path, params: { email: user.email, password: 'SecurePassword123!' }
      session_id = session[:user_id]

      get root_path
      expect(session[:user_id]).to eq(session_id)
    end

    it 'uses same session after logout' do
      post login_path, params: { email: user.email, password: 'SecurePassword123!' }
      original_session = session[:user_id]

      delete logout_path
      expect(session[:user_id]).to be_nil
      expect(session[:user_id]).not_to eq(original_session)
    end
  end

  describe 'Unauthenticated routes' do
    it 'allows access to login without authentication' do
      get login_path
      expect(response).to be_successful
    end

    it 'allows access to signup without authentication' do
      get sign_up_path
      expect(response).to be_successful
    end

    it 'allows POST to login without authentication' do
      user = create(:user)
      post login_path, params: { email: user.email, password: 'SecurePassword123!' }
      expect(response).to redirect_to(root_path)
    end

    it 'allows POST to signup without authentication' do
      post sign_up_path, params: {
        user: {
          email: 'new@example.com',
          password: 'SecurePassword123!',
          password_confirmation: 'SecurePassword123!'
        }
      }
      expect(response).to redirect_to(root_path)
    end
  end
end
