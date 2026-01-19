require 'rails_helper'

RSpec.describe DownloadCardImagesJob, type: :job do
  include ActiveJob::TestHelper

  let(:card_set) { create(:card_set, download_status: :downloading) }
  let(:card) { create(:card, :without_image_uris, card_set: card_set, image_path: nil) }

  before do
    # Mock image download to return a path
    allow(ScryfallService).to receive(:download_card_image).and_return('card_images/test.jpg')
  end

  describe '#perform' do
    it 'downloads the card image' do
      expect(ScryfallService).to receive(:download_card_image).with(card.to_image_hash)

      perform_enqueued_jobs do
        described_class.perform_later(card.id)
      end
    end

    it 'updates the card image_path' do
      perform_enqueued_jobs do
        described_class.perform_later(card.id)
      end

      expect(card.reload.image_path).to eq('card_images/test.jpg')
    end

    it 'broadcasts card image ready via ActionCable' do
      expect {
        perform_enqueued_jobs do
          described_class.perform_later(card.id)
        end
      }.to have_broadcasted_to("card_image:#{card.id}").with(
        hash_including(
          type: 'image_ready',
          card_id: card.id,
          image_path: 'card_images/test.jpg'
        )
      )
    end

    it 'updates set progress' do
      perform_enqueued_jobs do
        described_class.perform_later(card.id)
      end

      expect(card_set.reload.images_downloaded).to eq(1)
    end

    context 'when image download fails' do
      before do
        allow(ScryfallService).to receive(:download_card_image).and_return(nil)
      end

      it 'does not update image_path' do
        perform_enqueued_jobs do
          described_class.perform_later(card.id)
        end

        expect(card.reload.image_path).to be_nil
      end

      it 'does not broadcast card image ready' do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(card.id)
          end
        }.not_to have_broadcasted_to("card_image:#{card.id}")
      end
    end

    context 'with double-faced card' do
      let(:dfc_card) { create(:card, :double_faced, :without_image_uris, card_set: card_set, image_path: nil, back_image_path: nil) }

      before do
        allow(ScryfallService).to receive(:download_card_image)
          .with(dfc_card.to_image_hash)
          .and_return('card_images/dfc_front.jpg')
        allow(ScryfallService).to receive(:download_card_image)
          .with(dfc_card.to_back_image_hash, suffix: '_back')
          .and_return('card_images/dfc_back.jpg')
      end

      it 'downloads both front and back images' do
        expect(ScryfallService).to receive(:download_card_image).with(dfc_card.to_image_hash)
        expect(ScryfallService).to receive(:download_card_image).with(dfc_card.to_back_image_hash, suffix: '_back')

        perform_enqueued_jobs do
          described_class.perform_later(dfc_card.id)
        end
      end

      it 'updates both image paths' do
        perform_enqueued_jobs do
          described_class.perform_later(dfc_card.id)
        end

        dfc_card.reload
        expect(dfc_card.image_path).to eq('card_images/dfc_front.jpg')
        expect(dfc_card.back_image_path).to eq('card_images/dfc_back.jpg')
      end

      it 'broadcasts with both image paths' do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(dfc_card.id)
          end
        }.to have_broadcasted_to("card_image:#{dfc_card.id}").with(
          hash_including(
            type: 'image_ready',
            card_id: dfc_card.id,
            image_path: 'card_images/dfc_front.jpg',
            back_image_path: 'card_images/dfc_back.jpg'
          )
        )
      end
    end

    context 'when all images are downloaded' do
      before do
        # Create a set with only this card
        card_set.update!(card_count: 1)
      end

      it 'marks set as completed' do
        perform_enqueued_jobs do
          described_class.perform_later(card.id)
        end

        expect(card_set.reload.download_status).to eq('completed')
      end
    end

    context 'when card is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.perform_now('non-existent-id')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when ScryfallService raises an error' do
      before do
        allow(ScryfallService).to receive(:download_card_image).and_raise(StandardError.new('Network error'))
      end

      it 're-raises the error for retry' do
        expect {
          described_class.perform_now(card.id)
        }.to raise_error(StandardError, 'Network error')
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)
        begin
          described_class.perform_now(card.id)
        rescue StandardError
          # Expected
        end
        expect(Rails.logger).to have_received(:error).with(/Error downloading image/)
      end
    end

    context 'when card already has image downloaded' do
      let(:card_with_image) { create(:card, card_set: card_set, image_path: 'card_images/existing.jpg') }

      it 'does not download again' do
        expect(ScryfallService).not_to receive(:download_card_image)
        described_class.perform_now(card_with_image.id)
      end
    end

    context 'when double-faced card has back image but not front' do
      let(:dfc_card) do
        create(:card, :double_faced, card_set: card_set,
               image_path: nil, back_image_path: 'card_images/back.jpg')
      end

      before do
        allow(ScryfallService).to receive(:download_card_image)
          .with(dfc_card.to_image_hash)
          .and_return('card_images/front.jpg')
      end

      it 'downloads only front image' do
        expect(ScryfallService).to receive(:download_card_image)
          .with(dfc_card.to_image_hash)
          .once

        described_class.perform_now(dfc_card.id)

        expect(dfc_card.reload.image_path).to eq('card_images/front.jpg')
      end
    end

    context 'when double-faced card front download succeeds but back fails' do
      let(:dfc_card) { create(:card, :double_faced, card_set: card_set, image_path: nil, back_image_path: nil) }

      before do
        allow(ScryfallService).to receive(:download_card_image)
          .with(dfc_card.to_image_hash)
          .and_return('card_images/front.jpg')
        allow(ScryfallService).to receive(:download_card_image)
          .with(dfc_card.to_back_image_hash, suffix: '_back')
          .and_return(nil)
      end

      it 'still broadcasts with front image' do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(dfc_card.id)
          end
        }.to have_broadcasted_to("card_image:#{dfc_card.id}").with(
          hash_including(
            type: 'image_ready',
            image_path: 'card_images/front.jpg',
            back_image_path: nil
          )
        )
      end
    end

    context 'when set has more cards to download' do
      before do
        card_set.update!(card_count: 100)
        create_list(:card, 5, card_set: card_set, image_path: 'card_images/existing.jpg')
      end

      it 'does not mark set as completed' do
        perform_enqueued_jobs do
          described_class.perform_later(card.id)
        end

        expect(card_set.reload.download_status).to eq('downloading')
      end
    end
  end
end
