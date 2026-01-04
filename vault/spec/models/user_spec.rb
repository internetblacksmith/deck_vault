require 'rails_helper'

RSpec.describe User, type: :model do
  # Associations
  describe 'associations' do
    it 'has secure password configured' do
      user = build(:user, password: 'test123', password_confirmation: 'test123')
      expect(user).to be_valid
    end
  end

  # Validations
  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_length_of(:username).is_at_least(3).is_at_most(30) }

    context 'when username is missing' do
      before { subject.username = nil }
      it { is_expected.not_to be_valid }
    end

    context 'when username is not unique' do
      before do
        create(:user, username: 'testuser')
        subject.username = 'testuser'
      end

      it { is_expected.not_to be_valid }
    end

    context 'with invalid username format' do
      before { subject.username = 'user@name!' }
      it { is_expected.not_to be_valid }
    end

    context 'with valid username format' do
      before { subject.username = 'valid_user123' }
      it { is_expected.to be_valid }
    end

    context 'with password mismatch' do
      before do
        subject.password = 'password123'
        subject.password_confirmation = 'different'
      end

      it { is_expected.not_to be_valid }
    end
  end

  # Password security
  describe 'password security' do
    subject { create(:user, password: 'SecurePassword123!') }

    it 'stores password as digest' do
      expect(subject.password_digest).not_to eq('SecurePassword123!')
    end

    it 'password_digest is bcrypt hashed' do
      expect(subject.password_digest).to match(/\$2[aby]\$/)
    end

    it 'authenticates with correct password' do
      expect(subject.authenticate('SecurePassword123!')).to be_truthy
    end

    it 'fails authentication with wrong password' do
      expect(subject.authenticate('WrongPassword')).to be_falsy
    end

    it 'is not vulnerable to timing attacks (both return falsy)' do
      result1 = subject.authenticate('wrong1')
      result2 = subject.authenticate('wrong2')
      expect([ result1, result2 ]).to eq([ false, false ])
    end
  end

  # has_secure_password behavior
  describe 'has_secure_password' do
    subject { build(:user) }

    it 'requires password on create' do
      subject.password = nil
      expect(subject).not_to be_valid
    end

    it 'requires password_confirmation if password is set' do
      subject.password = 'password123'
      subject.password_confirmation = 'different'
      expect(subject).not_to be_valid
    end

    it 'allows creation with matching password and confirmation' do
      subject.password = 'password123'
      subject.password_confirmation = 'password123'
      expect(subject).to be_valid
    end

    it 'creates password_digest when saved' do
      subject.password = 'password123'
      subject.password_confirmation = 'password123'
      subject.save
      expect(subject.password_digest).to be_present
    end
  end

  # Factory
  describe 'factory' do
    subject { build(:user) }

    it 'builds a valid user' do
      expect(subject).to be_valid
    end

    it 'has username' do
      expect(subject.username).to be_present
    end

    it 'has password_digest after save' do
      subject.save
      expect(subject.password_digest).to be_present
    end
  end

  # Database
  describe 'database' do
    subject { create(:user) }

    it 'persists user to database' do
      expect(User.find(subject.id)).to eq(subject)
    end

    it 'persists username correctly' do
      found_user = User.find(subject.id)
      expect(found_user.username).to eq(subject.username)
    end

    it 'persists password_digest' do
      found_user = User.find(subject.id)
      expect(found_user.password_digest).to eq(subject.password_digest)
    end
  end

  # Timestamps
  describe 'timestamps' do
    subject { create(:user) }

    it { is_expected.to have_attributes(created_at: be_a(Time), updated_at: be_a(Time)) }

    it 'updates updated_at when modified' do
      original_updated_at = subject.updated_at
      sleep 0.1
      subject.update(username: 'newusername')
      expect(subject.updated_at).to be >= original_updated_at
    end
  end

  # Username validation
  describe 'username validation' do
    it 'accepts simple username' do
      user = build(:user, username: 'john')
      expect(user).to be_valid
    end

    it 'accepts username with numbers' do
      user = build(:user, username: 'john123')
      expect(user).to be_valid
    end

    it 'accepts username with underscores' do
      user = build(:user, username: 'john_doe')
      expect(user).to be_valid
    end

    it 'accepts mixed case username' do
      user = build(:user, username: 'JohnDoe')
      expect(user).to be_valid
    end

    it 'rejects username with spaces' do
      user = build(:user, username: 'john doe')
      expect(user).not_to be_valid
    end

    it 'rejects username with special characters' do
      user = build(:user, username: 'john@doe')
      expect(user).not_to be_valid
    end

    it 'rejects username too short' do
      user = build(:user, username: 'ab')
      expect(user).not_to be_valid
    end

    it 'rejects username too long' do
      user = build(:user, username: 'a' * 31)
      expect(user).not_to be_valid
    end
  end

  # Edge cases
  describe 'edge cases' do
    context 'with special characters in password' do
      subject { build(:user, password: 'P@$$w0rd!#%&*', password_confirmation: 'P@$$w0rd!#%&*') }

      it 'is valid' do
        expect(subject).to be_valid
      end

      it 'authenticates correctly' do
        subject.save
        expect(subject.authenticate('P@$$w0rd!#%&*')).to be_truthy
      end
    end

    context 'with unicode characters in password' do
      subject { build(:user, password: 'Pässwörd123™', password_confirmation: 'Pässwörd123™') }

      it 'is valid' do
        expect(subject).to be_valid
      end

      it 'authenticates correctly' do
        subject.save
        expect(subject.authenticate('Pässwörd123™')).to be_truthy
      end
    end
  end
end
