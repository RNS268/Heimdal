const mongoose = require("mongoose");

const SUPPORTED_DEVICE_TYPES = ["helmet", "heart_rate"];
const SUPPORTED_CAPABILITIES = ["crash_detection", "telemetry", "heart_rate"];

const deviceSchema = new mongoose.Schema(
  {
    device_id: { type: String, required: true, trim: true },
    user_id: { type: String, required: true, index: true, trim: true },
    name: { type: String, required: true, trim: true },
    type: { type: String, enum: SUPPORTED_DEVICE_TYPES, required: true },
    is_connected: { type: Boolean, required: true, default: false },
    last_seen: { type: Date, required: true, default: Date.now },
    capabilities: {
      type: [String],
      enum: SUPPORTED_CAPABILITIES,
      default: []
    }
  },
  { timestamps: true }
);

deviceSchema.index({ user_id: 1, device_id: 1 }, { unique: true });
deviceSchema.index({ user_id: 1, type: 1, is_connected: 1 });
deviceSchema.index(
  { user_id: 1, type: 1, is_connected: 1 },
  {
    unique: true,
    partialFilterExpression: { type: "helmet", is_connected: true }
  }
);

module.exports = {
  Device: mongoose.model("Device", deviceSchema),
  SUPPORTED_DEVICE_TYPES,
  SUPPORTED_CAPABILITIES
};
