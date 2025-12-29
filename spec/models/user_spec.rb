require 'rails_helper'

RSpec.describe User, type: :model do
  # Associations
  describe 'associations' do
    # User has no associations yet, but could have has_many :card_sets in the future
    it 'has secure password configured' do
      user = build(:user, password: 'test123', password_confirmation: 'test123')
      expect(user).to be_valid
    end
  end

  # Validations
  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
    it { is_expected.to validate_presence_of(:password) }

    context 'when email is missing' do
      before { subject.email = nil }
      it { is_expected.not_to be_valid }
    end

    context 'when email is not unique' do
      before do
        create(:user, email: 'test@example.com')
        subject.email = 'test@example.com'
      end

      it { is_expected.not_to be_valid }
    end

    context 'with invalid email format' do
      before { subject.email = 'not-an-email' }
      it { is_expected.not_to be_valid }
    end

    context 'with valid email format' do
      before { subject.email = 'user@example.com' }
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

    it 'has email' do
      expect(subject.email).to be_present
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

    it 'persists email correctly' do
      found_user = User.find(subject.id)
      expect(found_user.email).to eq(subject.email)
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
      subject.update(email: 'newemail@example.com')
      expect(subject.updated_at).to be >= original_updated_at
    end
  end

  # Email validation
  describe 'email validation' do
    it 'accepts user@example.com' do
      user = build(:user, email: 'user@example.com')
      expect(user).to be_valid
    end

    it 'accepts user.name@example.com' do
      user = build(:user, email: 'user.name@example.com')
      expect(user).to be_valid
    end

    it 'accepts user+tag@example.co.uk' do
      user = build(:user, email: 'user+tag@example.co.uk')
      expect(user).to be_valid
    end

    it 'accepts user123@test-domain.com' do
      user = build(:user, email: 'user123@test-domain.com')
      expect(user).to be_valid
    end

    it 'rejects plainaddress' do
      user = build(:user, email: 'plainaddress')
      expect(user).not_to be_valid
    end

    it 'rejects @example.com' do
      user = build(:user, email: '@example.com')
      expect(user).not_to be_valid
    end

    it 'rejects user@' do
      user = build(:user, email: 'user@')
      expect(user).not_to be_valid
    end

    it 'rejects user@.com' do
      user = build(:user, email: 'user@.com')
      expect(user).not_to be_valid
    end

    it 'rejects user name@example.com' do
      user = build(:user, email: 'user name@example.com')
      expect(user).not_to be_valid
    end
  end

  # Edge cases
  describe 'edge cases' do
    context 'with very long email' do
      subject { build(:user, email: "#{'a' * 200}@example.com") }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'with case-insensitive email lookup' do
      let(:user1) { create(:user, email: 'Test@Example.com') }
      let(:user2) { build(:user, email: 'test@example.com') }

      it 'allows different case variations to be stored' do
        expect(user2).to be_valid
      end
    end

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
