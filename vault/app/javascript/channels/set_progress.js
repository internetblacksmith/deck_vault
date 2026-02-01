import consumer from "channels/consumer"

export function subscribeToSetProgress(setId, onUpdate) {
  const subscription = consumer.subscriptions.create(
    { channel: "SetProgressChannel", card_set_id: setId },
    {
      connected() {},
      received(data) {
        onUpdate(data)
      },
      disconnected() {}
    }
  )
  
  return subscription
}
