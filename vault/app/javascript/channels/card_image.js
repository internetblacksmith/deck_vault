import consumer from "channels/consumer"

export function subscribeToCardImage(cardId, onImageReady) {
  const subscription = consumer.subscriptions.create(
    { channel: "CardImageChannel", card_id: cardId },
    {
      connected() {
        console.log(`Connected to image updates for card ${cardId}`)
      },
      received(data) {
        console.log('Card image update received:', data)
        if (data.type === 'image_ready') {
          onImageReady(data)
          // Unsubscribe after receiving the image - no longer needed
          subscription.unsubscribe()
        }
      },
      disconnected() {
        console.log(`Disconnected from image updates for card ${cardId}`)
      }
    }
  )

  return subscription
}
