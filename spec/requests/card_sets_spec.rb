require 'rails_helper'

RSpec.describe 'Card Sets', type: :request do
  before do
    @user = create(:user)
    post login_path, params: { username: @user.username, password: 'SecurePassword123!' }
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
    end
  end

  describe 'GET /card_sets/available_sets' do
    before do
      allow(ScryfallService).to receive(:fetch_sets).and_return([
        { code: 'TST', name: 'Test Set', card_count: 100, released_at: '2024-01-01', parent_set_code: nil, set_type: 'expansion' }
      ])
    end

    it 'returns JSON' do
      get available_sets_card_sets_path
      expect(response.content_type).to include('application/json')
    end

    it 'includes set data' do
      get available_sets_card_sets_path
      json = JSON.parse(response.body)
      expect(json.first['name']).to eq('Test Set')
      expect(json.first['code']).to eq('TST')
    end

    it 'includes download status' do
      create(:card_set, code: 'TST', name: 'Test Set')
      get available_sets_card_sets_path
      json = JSON.parse(response.body)
      expect(json.first['downloaded']).to be true
      expect(json.first['downloaded_id']).to be_present
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
  end

  describe 'PATCH /card_sets/:id/update_card' do
    let(:card_set) { create(:card_set) }
    let(:card) { create(:card, card_set: card_set) }

    context 'with valid parameters' do
      let(:valid_params) do
        {
          card_id: card.id,
          quantity: 2,
          foil_quantity: 1,
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
        # Use includes to eager load association and avoid strict loading violation
        collection_card = Card.includes(:collection_card).find(card.id).collection_card
        expect(collection_card.quantity).to eq(2)
        expect(collection_card.foil_quantity).to eq(1)
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
          quantity: -1
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
          quantity: 1
        }
      end

      it 'returns not_found status with error' do
        patch update_card_card_set_path(card_set), params: invalid_params
        expect(response).to have_http_status(404)
        expect(response.content_type).to include('vnd.turbo-stream.html')
      end
    end

    context 'updating existing collection_card' do
      let!(:collection_card) { create(:collection_card, card: card, quantity: 1, foil_quantity: 0) }
      let(:update_params) do
        {
          card_id: card.id,
          quantity: 3,
          foil_quantity: 2
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
        expect(collection_card.reload.foil_quantity).to eq(2)
      end
    end

    context 'with quantity zero' do
      let(:params_zero_qty) do
        {
          card_id: card.id,
          quantity: 0
        }
      end

      it 'is valid' do
        patch update_card_card_set_path(card_set), params: params_zero_qty
        expect(response).to be_successful
      end
    end

    context 'with foil_quantity' do
      it 'accepts foil_quantity updates' do
        params = { card_id: card.id, quantity: 1, foil_quantity: 3 }
        patch update_card_card_set_path(card_set), params: params
        expect(response).to be_successful
        collection_card = Card.includes(:collection_card).find(card.id).collection_card
        expect(collection_card.foil_quantity).to eq(3)
      end

      it 'accepts foil_quantity zero' do
        params = { card_id: card.id, quantity: 2, foil_quantity: 0 }
        patch update_card_card_set_path(card_set), params: params
        expect(response).to be_successful
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

  describe 'DELETE /card_sets/:id' do
    let!(:card_set) { create(:card_set, name: 'Test Set to Delete', code: 'DEL') }

    context 'when set exists' do
      it 'destroys the card_set' do
        expect {
          delete card_set_path(card_set)
        }.to change(CardSet, :count).by(-1)
      end

      it 'redirects to index with notice' do
        delete card_set_path(card_set)
        expect(response).to redirect_to(card_sets_path)
        follow_redirect!
        expect(response.body).to include('Test Set to Delete has been deleted')
      end

      context 'with associated cards' do
        let!(:card1) { create(:card, card_set: card_set, scryfall_id: 'del-card-1') }
        let!(:card2) { create(:card, card_set: card_set, scryfall_id: 'del-card-2') }

        it 'destroys associated cards' do
          expect {
            delete card_set_path(card_set)
          }.to change(Card, :count).by(-2)
        end

        context 'with collection cards' do
          let!(:collection_card) { create(:collection_card, card: card1) }

          it 'destroys associated collection cards' do
            expect {
              delete card_set_path(card_set)
            }.to change(CollectionCard, :count).by(-1)
          end
        end
      end

      context 'with image files' do
        let!(:card) { create(:card, card_set: card_set, image_path: 'card_images/test_delete.jpg', scryfall_id: 'del-card-img') }

        before do
          # Create a test image file
          FileUtils.mkdir_p(Rails.root.join('storage', 'card_images'))
          File.write(Rails.root.join('storage', 'card_images', 'test_delete.jpg'), 'test')
        end

        after do
          # Cleanup in case test fails
          FileUtils.rm_f(Rails.root.join('storage', 'card_images', 'test_delete.jpg'))
        end

        it 'deletes the image file' do
          file_path = Rails.root.join('storage', 'card_images', 'test_delete.jpg')
          expect(File.exist?(file_path)).to be true

          delete card_set_path(card_set)

          expect(File.exist?(file_path)).to be false
        end
      end
    end

    context 'when set does not exist' do
      it 'returns 404 error' do
        delete card_set_path(9999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /card_sets/:id/retry_images' do
    let(:card_set) { create(:card_set, download_status: :completed) }

    context 'when all images are downloaded' do
      before do
        create(:card, card_set: card_set, image_path: 'card_images/test.jpg', scryfall_id: 'retry-1')
      end

      it 'returns success message' do
        post retry_images_card_set_path(card_set)
        expect(response).to redirect_to(card_set_path(card_set))
        follow_redirect!
        expect(response.body).to include('All images already downloaded')
      end

      it 'does not queue jobs' do
        expect {
          post retry_images_card_set_path(card_set)
        }.not_to have_enqueued_job(DownloadCardImagesJob)
      end
    end

    context 'when images are missing' do
      before do
        create(:card, card_set: card_set, image_path: nil, scryfall_id: 'retry-2')
        create(:card, card_set: card_set, image_path: nil, scryfall_id: 'retry-3')

        # Stub Scryfall API response
        stub_request(:get, %r{api.scryfall.com/cards/})
          .to_return(
            status: 200,
            body: {
              id: 'retry-2',
              name: 'Test Card',
              image_uris: { normal: 'https://example.com/image.jpg' }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'redirects with retry message' do
        post retry_images_card_set_path(card_set)
        expect(response).to redirect_to(card_set_path(card_set))
        follow_redirect!
        expect(response.body).to include('Retrying download for 2 images')
      end

      it 'queues download jobs for missing images' do
        expect {
          post retry_images_card_set_path(card_set)
        }.to have_enqueued_job(DownloadCardImagesJob).exactly(2).times
      end

      it 'sets download_status to downloading' do
        post retry_images_card_set_path(card_set)
        expect(card_set.reload.download_status).to eq('downloading')
      end
    end

    context 'when set does not exist' do
      it 'returns 404 error' do
        post retry_images_card_set_path(9999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /card_sets/:id/update_binder_settings' do
    let(:card_set) { create(:card_set) }

    context 'with valid parameters' do
      let(:valid_params) do
        {
          binder_rows: 4,
          binder_columns: 3,
          binder_sort_field: 'name',
          binder_sort_direction: 'desc'
        }
      end

      it 'returns success response for JSON format' do
        patch update_binder_settings_card_set_path(card_set, format: :json), params: valid_params
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end

      it 'updates binder_rows' do
        patch update_binder_settings_card_set_path(card_set, format: :json), params: valid_params
        expect(card_set.reload.binder_rows).to eq(4)
      end

      it 'updates binder_columns' do
        patch update_binder_settings_card_set_path(card_set, format: :json), params: valid_params
        expect(card_set.reload.binder_columns).to eq(3)
      end

      it 'updates binder_sort_field' do
        patch update_binder_settings_card_set_path(card_set, format: :json), params: valid_params
        expect(card_set.reload.binder_sort_field).to eq('name')
      end

      it 'updates binder_sort_direction' do
        patch update_binder_settings_card_set_path(card_set, format: :json), params: valid_params
        expect(card_set.reload.binder_sort_direction).to eq('desc')
      end

      it 'redirects for HTML format' do
        patch update_binder_settings_card_set_path(card_set), params: valid_params
        expect(response).to redirect_to(card_set_path(card_set, view_type: 'binder'))
      end
    end

    context 'with partial parameters' do
      it 'updates only provided fields' do
        patch update_binder_settings_card_set_path(card_set, format: :json), params: { binder_rows: 5 }
        expect(card_set.reload.binder_rows).to eq(5)
        # Other fields should remain at defaults
        expect(card_set.binder_columns).to eq(3)
      end
    end

    context 'when set does not exist' do
      it 'returns 404 error' do
        patch update_binder_settings_card_set_path(9999, format: :json), params: { binder_rows: 4 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
