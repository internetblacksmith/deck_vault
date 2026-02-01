import consumer from "channels/consumer"

export function subscribeToCardImage(cardId, onImageReady) {
  const subscription = consumer.subscriptions.create(
    { channel: "CardImageChannel", card_id: cardId },
    {
      connected() {},
      received(data) {
        if (data.type === 'image_ready') {
          onImageReady(data)
          // Unsubscribe after receiving the image - no longer needed
          subscription.unsubscribe()
        }
      },
      disconnected() {}
    }
  )

  return subscription
}
