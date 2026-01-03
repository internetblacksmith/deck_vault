RSpec.shared_examples "a valid model" do
  it { is_expected.to be_valid }
end

RSpec.shared_examples "timestamps" do
  it { is_expected.to have_attributes(created_at: be_a(Time), updated_at: be_a(Time)) }
end

RSpec.shared_examples "validations" do
  subject { described_class.new(valid_attributes) }
  let(:valid_attributes) { {} }

  it { is_expected.to be_valid }
end
