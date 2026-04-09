const mongoose = require("mongoose");

const safetySettingSchema = new mongoose.Schema(
  {
    user_id: { type: String, required: true, unique: true, trim: true },
    crash_sensitivity: {
      type: String,
      enum: ["low", "medium", "high"],
      default: "medium",
      required: true
    },
    auto_sos: { type: Boolean, default: true, required: true }
  },
  { timestamps: true }
);

module.exports = {
  SafetySetting: mongoose.model("SafetySetting", safetySettingSchema)
};
