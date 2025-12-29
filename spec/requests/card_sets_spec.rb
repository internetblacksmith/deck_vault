require 'rails_helper'

RSpec.describe 'Card Sets', type: :request do
  before do
    @user = create(:user)
    post login_path, params: { email: @user.email, password: 'SecurePassword123!' }
  end
  describe 'GET /card_sets' do
    context 'with no sets' do
      it 'returns a successful response' do
        get card_sets_path
        expect(response).to be_successful
      end

      it 'returns HTML' do
        get card_sets_path
        expect(response.content_type).to include('text/html')
      end
    end

    context 'with downloaded sets' do
      before do
        create(:card_set, name: 'Test Set 1', code: 'TST')
        create(:card_set, name: 'Test Set 2', code: 'TS2')
      end

      it 'returns a successful response' do
        get card_sets_path
        expect(response).to be_successful
      end

      it 'includes set names in response' do
        get card_sets_path
        expect(response.body).to include('Test Set 1')
        expect(response.body).to include('Test Set 2')
      end

      it 'sets cache headers' do
        get card_sets_path
        expect(response.headers['Cache-Control']).to include('public')
      end
    end
  end

  describe 'GET /card_sets/:id' do
    let(:card_set) { create(:card_set) }

    context 'when set exists' do
      it 'returns a successful response' do
        get card_set_path(card_set)
        expect(response).to be_successful
      end

      it 'returns HTML' do
        get card_set_path(card_set)
        expect(response.content_type).to include('text/html')
      end
    end

    context 'when set does not exist' do
      it 'returns 404 error' do
        get card_set_path(9999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with view_type parameter' do
      %w[table grid binder].each do |view_type|
        it "accepts view_type=#{view_type}" do
          get card_set_path(card_set, view_type: view_type)
          expect(response).to be_successful
        end
      end
    end

    context 'with completed set' do
      before { card_set.update(download_status: :completed) }

      it 'sets aggressive cache headers' do
        get card_set_path(card_set)
        expect(response.headers['Cache-Control']).to include('public')
        expect(response.headers['Cache-Control']).to include('max-age')
      end
    end

    context 'with downloading set' do
      before { card_set.update(download_status: :downloading) }

      it 'sets no-cache headers' do
        get card_set_path(card_set)
        expect(response.headers['Cache-Control']).to include('private')
      end
    end
  end

  describe 'PATCH /card_sets/:id/update_card' do
    let(:card_set) { create(:card_set) }
    let(:card) { create(:card, card_set: card_set) }

    context 'with valid parameters' do
      let(:valid_params) do
        {
          card_id: card.id,
          quantity: 2,
          page_number: 5,
          notes: 'Test note'
        }
      end

      it 'returns a successful response' do
        patch update_card_card_set_path(card_set), params: valid_params
        expect(response).to be_successful
      end

      it 'creates collection_card' do
        expect {
          patch update_card_card_set_path(card_set), params: valid_params
        }.to change(CollectionCard, :count).by(1)
      end

      it 'updates collection_card attributes' do
        patch update_card_card_set_path(card_set), params: valid_params
        collection_card = card.reload.collection_card
        expect(collection_card.quantity).to eq(2)
        expect(collection_card.page_number).to eq(5)
        expect(collection_card.notes).to eq('Test note')
      end

      it 'returns Turbo Stream response' do
        patch update_card_card_set_path(card_set), params: valid_params
        expect(response.content_type).to include('vnd.turbo-stream.html')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          card_id: card.id,
          quantity: -1,
          page_number: 5
        }
      end

      it 'returns unprocessable_entity status' do
        patch update_card_card_set_path(card_set), params: invalid_params
        expect(response).to have_http_status(422)
      end

      it 'returns error in Turbo Stream' do
        patch update_card_card_set_path(card_set), params: invalid_params
        expect(response.content_type).to include('vnd.turbo-stream.html')
      end
    end

    context 'when card does not exist' do
      let(:invalid_params) do
        {
          card_id: 9999,
          quantity: 1,
          page_number: 1
        }
      end

      it 'returns not_found status with error' do
        patch update_card_card_set_path(card_set), params: invalid_params
        expect(response).to have_http_status(404)
        expect(response.content_type).to include('vnd.turbo-stream.html')
      end
    end

    context 'updating existing collection_card' do
      let!(:collection_card) { create(:collection_card, card: card, quantity: 1) }
      let(:update_params) do
        {
          card_id: card.id,
          quantity: 3,
          page_number: 10
        }
      end

      it 'does not create new collection_card' do
        expect {
          patch update_card_card_set_path(card_set), params: update_params
        }.not_to change(CollectionCard, :count)
      end

      it 'updates existing collection_card' do
        patch update_card_card_set_path(card_set), params: update_params
        expect(collection_card.reload.quantity).to eq(3)
        expect(collection_card.reload.page_number).to eq(10)
      end
    end

    context 'with quantity zero' do
      let(:params_zero_qty) do
        {
          card_id: card.id,
          quantity: 0,
          page_number: 1
        }
      end

      it 'is valid' do
        patch update_card_card_set_path(card_set), params: params_zero_qty
        expect(response).to be_successful
      end
    end

    context 'with page_number at boundary' do
      it 'accepts page 1' do
        params = { card_id: card.id, quantity: 1, page_number: 1 }
        patch update_card_card_set_path(card_set), params: params
        expect(response).to be_successful
      end

      it 'accepts page 200' do
        params = { card_id: card.id, quantity: 1, page_number: 200 }
        patch update_card_card_set_path(card_set), params: params
        expect(response).to be_successful
      end

      it 'rejects page 0' do
        params = { card_id: card.id, quantity: 1, page_number: 0 }
        patch update_card_card_set_path(card_set), params: params
        expect(response).to have_http_status(422)
      end

      it 'rejects page 201' do
        params = { card_id: card.id, quantity: 1, page_number: 201 }
        patch update_card_card_set_path(card_set), params: params
        expect(response).to have_http_status(422)
      end
    end
  end

  describe 'POST /card_sets/download_set' do
    context 'with valid set code' do
      before do
        allow(ScryfallService).to receive(:download_set).and_return(create(:card_set))
      end

      it 'starts download' do
        post download_set_card_sets_path, params: { set_code: 'LEA' }
        expect(response).to redirect_to(card_set_path(CardSet.last))
      end

      it 'sets download_status to downloading' do
        card_set = create(:card_set, download_status: :pending)
        allow(ScryfallService).to receive(:download_set).and_return(card_set)

        post download_set_card_sets_path, params: { set_code: 'LEA' }
        expect(card_set.reload.download_status).to eq('downloading')
      end
    end

    context 'with invalid set code' do
      before do
        allow(ScryfallService).to receive(:download_set).and_return(nil)
      end

      it 'redirects to index with error' do
        post download_set_card_sets_path, params: { set_code: 'INVALID' }
        expect(response).to redirect_to(card_sets_path)
      end
    end
  end

  describe 'caching behavior' do
    let(:card_set) { create(:card_set) }

    it 'sets ETag header' do
      get card_set_path(card_set)
      expect(response.headers).to have_key('ETag')
    end

    it 'ETag changes when card_set is updated' do
      get card_set_path(card_set)
      etag1 = response.headers['ETag']

      card_set.touch
      get card_set_path(card_set)
      etag2 = response.headers['ETag']

      expect(etag2).not_to eq(etag1)
    end
  end
end
