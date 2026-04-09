function publishSettingsEvent(userId, eventType, payload) {
  // Replace with WebSocket, MQTT, or push provider in production.
  // Keeping this as a dedicated service keeps controllers decoupled.
  console.info(
    JSON.stringify({
      type: "settings_event",
      user_id: userId,
      event: eventType,
      payload,
      ts: new Date().toISOString()
    })
  );
}

module.exports = { publishSettingsEvent };
