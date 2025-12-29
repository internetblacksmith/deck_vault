import consumer from "channels/consumer"

export function subscribeToSetProgress(setId, onUpdate) {
  const subscription = consumer.subscriptions.create(
    { channel: "SetProgressChannel", card_set_id: setId },
    {
      connected() {
        console.log(`Connected to progress updates for set ${setId}`)
      },
      received(data) {
        console.log('Progress update received:', data)
        onUpdate(data)
      },
      disconnected() {
        console.log(`Disconnected from progress updates for set ${setId}`)
      }
    }
  )
  
  return subscription
}
