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

    context 'with sets containing cards and collection data' do
      let!(:card_set) { create(:card_set, name: 'Set With Cards', code: 'SWC') }
      let!(:card1) { create(:card, card_set: card_set, name: 'Card 1') }
      let!(:card2) { create(:card, card_set: card_set, name: 'Card 2') }
      let!(:collection_card) { create(:collection_card, card: card1, quantity: 2, foil_quantity: 0) }

      it 'returns a successful response without strict_loading errors' do
        get card_sets_path
        expect(response).to be_successful
      end

      it 'displays owned cards count correctly' do
        get card_sets_path
        # The page should render without errors and show the owned count
        expect(response.body).to include('Set With Cards')
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

    context 'with child sets (related sets)' do
      let!(:parent_set) { create(:card_set, code: 'MAIN', name: 'Main Set') }
      let!(:child_set1) { create(:card_set, code: 'PROMO', name: 'Promo Cards', parent_set_code: 'MAIN', set_type: 'promo') }
      let!(:child_set2) { create(:card_set, code: 'TOKEN', name: 'Tokens', parent_set_code: 'MAIN', set_type: 'token') }

      it 'displays related sets section in table view' do
        get card_set_path(parent_set, view_type: 'table')
        expect(response.body).to include('Related Sets')
      end

      it 'displays related sets section in grid view' do
        get card_set_path(parent_set, view_type: 'grid')
        expect(response.body).to include('Related Sets')
      end

      it 'displays related sets section in binder view' do
        get card_set_path(parent_set, view_type: 'binder')
        expect(response.body).to include('Related Sets')
      end

      context 'with include_subsets parameter' do
        let!(:parent_card) { create(:card, card_set: parent_set, name: 'Parent Card', collector_number: '1') }
        let!(:child_card) { create(:card, card_set: child_set1, name: 'Child Card', collector_number: '1') }

        it 'includes cards from child sets when include_subsets is true' do
          get card_set_path(parent_set, view_type: 'table', include_subsets: 'true')
          expect(response.body).to include('Parent Card')
          expect(response.body).to include('Child Card')
        end

        it 'shows combined stats highlighted when include_subsets is true' do
          get card_set_path(parent_set, view_type: 'table', include_subsets: 'true')
          # Combined row should be highlighted when include_subsets is active
          expect(response.body).to include('Combined *')
          expect(response.body).to include('Currently showing combined view')
          expect(response.body).to include('border-left:2px solid #4a4')
        end

        it 'does not include child set cards by default' do
          get card_set_path(parent_set, view_type: 'table')
          expect(response.body).to include('Parent Card')
          expect(response.body).not_to include('Child Card')
        end

        it 'works with binder view' do
          # Binder view uses saved DB setting, not URL parameter
          parent_set.update!(include_subsets: true)
          get card_set_path(parent_set, view_type: 'binder')
          expect(response.body).to include('Parent Card')
          expect(response.body).to include('Child Card')
        end

        it 'works with grid view' do
          get card_set_path(parent_set, view_type: 'grid', include_subsets: 'true')
          expect(response.body).to include('Parent Card')
          expect(response.body).to include('Child Card')
        end
      end

      it 'lists all child sets' do
        get card_set_path(parent_set)
        expect(response.body).to include('Promo Cards')
        expect(response.body).to include('Tokens')
      end
    end

    context 'without child sets' do
      let(:standalone) { create(:card_set, code: 'SOLO', name: 'Solo Set', parent_set_code: nil) }

      it 'does not show related sets section when no children exist' do
        expect(standalone.child_sets.count).to eq(0)
        get card_set_path(standalone)
        expect(response.body).not_to include('Related Sets')
      end
    end

    context 'stats table with Normal/Foil breakdown' do
      let!(:parent_set) { create(:card_set, code: 'TEST', name: 'Test Set') }
      let!(:child_set) { create(:card_set, code: 'TPROMO', name: 'Test Promos', parent_set_code: 'TEST', set_type: 'promo') }

      let!(:both_card) { create(:card, card_set: parent_set, name: 'Both Card', foil: true, nonfoil: true) }
      let!(:foil_only_card) { create(:card, card_set: parent_set, name: 'Foil Only', foil: true, nonfoil: false) }
      let!(:nonfoil_only_card) { create(:card, card_set: parent_set, name: 'Nonfoil Only', foil: false, nonfoil: true) }
      let!(:promo_card) { create(:card, card_set: child_set, name: 'Promo Card', foil: true, nonfoil: false) }

      it 'displays stats table headers' do
        get card_set_path(parent_set)
        expect(response.body).to include('Total')
        expect(response.body).to include('Normal')
        expect(response.body).to include('Foil')
        expect(response.body).to include('Images')
      end

      it 'displays Main Set row' do
        get card_set_path(parent_set)
        expect(response.body).to include('Main Set')
      end

      it 'displays Related row with child set count' do
        get card_set_path(parent_set)
        expect(response.body).to include('Related')
        expect(response.body).to include('(1)')
      end

      it 'displays Combined row' do
        get card_set_path(parent_set)
        expect(response.body).to include('Combined')
      end

      it 'shows correct Normal total (only nonfoil-available cards)' do
        get card_set_path(parent_set)
        # Main set has 2 cards with nonfoil: true (both_card and nonfoil_only_card)
        # The page should show 0/2 for Normal since none are owned
        expect(response.body).to include('0/2')
      end

      it 'shows correct Foil total (only foil-available cards)' do
        get card_set_path(parent_set)
        # Main set has 2 cards with foil: true (both_card and foil_only_card)
        # The page should show 0/2 for Foil since none are owned
        expect(response.body).to include('0/2')
      end
    end

    context 'binder view with double-faced cards' do
      let!(:dfc_set) { create(:card_set, code: 'DFC', name: 'DFC Set') }
      let!(:normal_card) { create(:card, card_set: dfc_set, name: 'Normal Card') }
      let!(:dfc_card) { create(:card, :double_faced, card_set: dfc_set, name: 'DFC Front // DFC Back') }

      it 'shows flip button for double-faced cards' do
        get card_set_path(dfc_set, view_type: 'binder')
        # DFC card should have flip button
        expect(response.body).to include('data-action="click->binder-card#flipCard"')
      end

      it 'shows edit button for all cards' do
        get card_set_path(dfc_set, view_type: 'binder')
        # All cards should have edit button
        expect(response.body).to include('data-action="click->binder-card#toggleEditor"')
      end

      it 'includes DFC data attributes for double-faced cards' do
        get card_set_path(dfc_set, view_type: 'binder')
        expect(response.body).to include('data-binder-card-is-dfc-value="true"')
      end

      it 'does not include DFC data attributes for normal cards' do
        get card_set_path(dfc_set, view_type: 'binder')
        expect(response.body).to include('data-binder-card-is-dfc-value="false"')
      end
    end

    context 'grid view with double-faced cards' do
      let!(:dfc_set) { create(:card_set, code: 'GDC', name: 'Grid DFC Set') }
      let!(:normal_card) { create(:card, card_set: dfc_set, name: 'Normal Grid Card') }
      let!(:dfc_card) { create(:card, :double_faced, card_set: dfc_set, name: 'Grid DFC Card') }

      it 'shows flip button for double-faced cards in grid view' do
        get card_set_path(dfc_set, view_type: 'grid')
        expect(response.body).to include('data-action="click->grid-card-flip#flipCard"')
      end

      it 'includes DFC data attributes for double-faced cards in grid view' do
        get card_set_path(dfc_set, view_type: 'grid')
        expect(response.body).to include('data-grid-card-flip-is-dfc-value="true"')
      end

      it 'includes back image data attribute for DFC in grid view' do
        get card_set_path(dfc_set, view_type: 'grid')
        expect(response.body).to include('data-grid-card-flip-back-image-value')
      end

      it 'does not show flip button for normal cards in grid view' do
        get card_set_path(dfc_set, view_type: 'grid')
        # Normal card should not have the flip button
        expect(response.body).to include('data-grid-card-flip-is-dfc-value="false"')
      end
    end

    context 'foil filter options' do
      let!(:filter_set) { create(:card_set, code: 'FLT', name: 'Filter Test Set') }
      let!(:foil_only_card) { create(:card, :foil_only, card_set: filter_set, name: 'Foil Only Card') }
      let!(:nonfoil_only_card) { create(:card, :nonfoil_only, card_set: filter_set, name: 'Nonfoil Only Card') }
      let!(:both_card) { create(:card, card_set: filter_set, name: 'Both Available Card', foil: true, nonfoil: true) }

      it 'includes foil filter options in grid view' do
        get card_set_path(filter_set, view_type: 'grid')
        expect(response.body).to include('Foil Only')
        expect(response.body).to include('Nonfoil Only')
      end

      it 'includes foil filter options in table view' do
        get card_set_path(filter_set, view_type: 'table')
        expect(response.body).to include('Foil Only')
        expect(response.body).to include('Nonfoil Only')
      end

      it 'includes foil data attributes on grid cards' do
        get card_set_path(filter_set, view_type: 'grid')
        expect(response.body).to include('data-is-foil="true"')
        expect(response.body).to include('data-is-nonfoil="true"')
      end

      it 'includes foil data attributes on table rows' do
        get card_set_path(filter_set, view_type: 'table')
        expect(response.body).to include('data-is-foil="true"')
        expect(response.body).to include('data-is-nonfoil="true"')
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
        let!(:card1) { create(:card, card_set: card_set, id: 'del-card-1') }
        let!(:card2) { create(:card, card_set: card_set, id: 'del-card-2') }

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
        let!(:card) { create(:card, card_set: card_set, image_path: 'card_images/test_delete.jpg', id: 'del-card-img') }

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
        create(:card, card_set: card_set, image_path: 'card_images/test.jpg', id: 'retry-1')
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
        create(:card, card_set: card_set, image_path: nil, id: 'retry-2')
        create(:card, card_set: card_set, image_path: nil, id: 'retry-3')

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

  describe 'GET /card_sets/export_collection' do
    context 'with collection cards' do
      let!(:card_set) { create(:card_set) }
      let!(:card1) { create(:card, card_set: card_set) }
      let!(:card2) { create(:card, card_set: card_set) }
      let!(:collection_card1) { create(:collection_card, card: card1, quantity: 2, foil_quantity: 1) }
      let!(:collection_card2) { create(:collection_card, card: card2, quantity: 0, foil_quantity: 3) }

      it 'returns JSON file' do
        get export_collection_card_sets_path
        expect(response).to be_successful
        expect(response.content_type).to include('application/json')
      end

      it 'includes collection data' do
        get export_collection_card_sets_path
        json = JSON.parse(response.body)
        expect(json['version']).to eq(1)
        expect(json['collection'].size).to eq(2)
      end

      it 'includes card_id, quantity, and foil_quantity' do
        get export_collection_card_sets_path
        json = JSON.parse(response.body)
        card_data = json['collection'].find { |c| c['card_id'] == card1.id }
        expect(card_data['quantity']).to eq(2)
        expect(card_data['foil_quantity']).to eq(1)
      end

      it 'sets attachment disposition' do
        get export_collection_card_sets_path
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include('.json')
      end
    end

    context 'with no collection cards' do
      it 'returns empty collection' do
        get export_collection_card_sets_path
        json = JSON.parse(response.body)
        expect(json['collection']).to eq([])
        expect(json['total_cards']).to eq(0)
      end
    end

    context 'with zero quantity cards' do
      let!(:card_set) { create(:card_set) }
      let!(:card) { create(:card, card_set: card_set) }
      let!(:collection_card) { create(:collection_card, card: card, quantity: 0, foil_quantity: 0) }

      it 'excludes cards with zero quantities' do
        get export_collection_card_sets_path
        json = JSON.parse(response.body)
        expect(json['collection']).to eq([])
      end
    end
  end

  describe 'POST /card_sets/import_collection' do
    let!(:card_set) { create(:card_set) }
    let!(:card1) { create(:card, card_set: card_set) }
    let!(:card2) { create(:card, card_set: card_set) }

    def upload_backup(data)
      file = Tempfile.new([ 'backup', '.json' ], binmode: true)
      file.write(data.is_a?(String) ? data : data.to_json)
      file.flush
      file.rewind
      Rack::Test::UploadedFile.new(file.path, 'application/json')
    end

    context 'with valid backup file' do
      it 'restores collection cards' do
        backup_data = {
          version: 1,
          collection: [
            { card_id: card1.id, quantity: 3, foil_quantity: 1 },
            { card_id: card2.id, quantity: 0, foil_quantity: 2 }
          ]
        }

        expect {
          post import_collection_card_sets_path, params: { backup_file: upload_backup(backup_data) }
        }.to change(CollectionCard, :count).by(2)
      end

      it 'sets correct quantities' do
        backup_data = {
          version: 1,
          collection: [
            { card_id: card1.id, quantity: 3, foil_quantity: 1 }
          ]
        }

        post import_collection_card_sets_path, params: { backup_file: upload_backup(backup_data) }

        collection_card = CollectionCard.find_by(card_id: card1.id)
        expect(collection_card.quantity).to eq(3)
        expect(collection_card.foil_quantity).to eq(1)
      end

      it 'redirects to index with success message' do
        backup_data = {
          version: 1,
          collection: [
            { card_id: card1.id, quantity: 3, foil_quantity: 1 },
            { card_id: card2.id, quantity: 0, foil_quantity: 2 }
          ]
        }

        post import_collection_card_sets_path, params: { backup_file: upload_backup(backup_data) }

        expect(response).to redirect_to(card_sets_path)
        expect(flash[:notice]).to include('Restored 2 cards')
      end
    end

    context 'with cards not in database' do
      it 'skips non-existent cards' do
        backup_data = {
          version: 1,
          collection: [
            { card_id: card1.id, quantity: 1, foil_quantity: 0 },
            { card_id: 'non-existent-card-id', quantity: 2, foil_quantity: 1 }
          ]
        }

        expect {
          post import_collection_card_sets_path, params: { backup_file: upload_backup(backup_data) }
        }.to change(CollectionCard, :count).by(1)
      end

      it 'shows skipped count in flash' do
        backup_data = {
          version: 1,
          collection: [
            { card_id: card1.id, quantity: 1, foil_quantity: 0 },
            { card_id: 'non-existent-card-id', quantity: 2, foil_quantity: 1 }
          ]
        }

        post import_collection_card_sets_path, params: { backup_file: upload_backup(backup_data) }

        expect(flash[:notice]).to include('skipped 1')
      end
    end

    context 'with invalid JSON' do
      it 'shows error in flash' do
        post import_collection_card_sets_path, params: { backup_file: upload_backup('invalid json') }

        expect(response).to redirect_to(card_sets_path)
        expect(flash[:alert]).to include('Invalid JSON file')
      end
    end

    context 'without file' do
      it 'shows error in flash' do
        post import_collection_card_sets_path

        expect(response).to redirect_to(card_sets_path)
        expect(flash[:alert]).to include('Please select a backup file')
      end
    end

    context 'updating existing collection cards' do
      let!(:existing_collection) { create(:collection_card, card: card1, quantity: 1, foil_quantity: 0) }

      it 'updates existing collection card' do
        backup_data = {
          version: 1,
          collection: [
            { card_id: card1.id, quantity: 5, foil_quantity: 2 }
          ]
        }

        expect {
          post import_collection_card_sets_path, params: { backup_file: upload_backup(backup_data) }
        }.not_to change(CollectionCard, :count)

        existing_collection.reload
        expect(existing_collection.quantity).to eq(5)
        expect(existing_collection.foil_quantity).to eq(2)
      end
    end
  end

  describe 'POST /card_sets/:id/refresh_cards' do
    let(:card_set) { create(:card_set, code: 'TST') }

    context 'when refresh succeeds' do
      before do
        allow(ScryfallService).to receive(:refresh_set).and_return({ added: 5, updated: 10 })
      end

      it 'redirects with success message' do
        post refresh_cards_card_set_path(card_set)
        expect(response).to redirect_to(card_set_path(card_set))
        follow_redirect!
        expect(response.body).to include('5 new cards added')
      end

      it 'returns JSON response when requested' do
        post refresh_cards_card_set_path(card_set, format: :json)
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['added']).to eq(5)
        expect(json['updated']).to eq(10)
      end
    end

    context 'when refresh fails' do
      before do
        allow(ScryfallService).to receive(:refresh_set).and_return({ added: 0, updated: 0, error: 'API error' })
      end

      it 'redirects with error message' do
        post refresh_cards_card_set_path(card_set)
        expect(response).to redirect_to(card_set_path(card_set))
        follow_redirect!
        expect(response.body).to include('Refresh failed')
      end

      it 'returns error JSON when requested' do
        post refresh_cards_card_set_path(card_set, format: :json)
        expect(response).to have_http_status(422)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to eq('API error')
      end
    end

    context 'when set does not exist' do
      it 'returns 404 error' do
        post refresh_cards_card_set_path(9999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
