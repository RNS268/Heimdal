const mongoose = require("mongoose");

const deviceCommandSchema = new mongoose.Schema(
  {
    user_id: { type: String, required: true, index: true, trim: true },
    device_id: { type: String, required: true, trim: true },
    command_type: { type: String, required: true, trim: true },
    payload: { type: mongoose.Schema.Types.Mixed, default: {} },
    status: {
      type: String,
      enum: ["pending", "sent", "failed"],
      default: "pending"
    }
  },
  { timestamps: true }
);

module.exports = {
  DeviceCommand: mongoose.model("DeviceCommand", deviceCommandSchema)
};
