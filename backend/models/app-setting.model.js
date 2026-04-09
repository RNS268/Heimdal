const mongoose = require("mongoose");

const appSettingSchema = new mongoose.Schema(
  {
    user_id: { type: String, required: true, unique: true, trim: true },
    theme: {
      type: String,
      enum: ["dark", "light"],
      default: "dark",
      required: true
    },
    units: {
      type: String,
      enum: ["metric", "imperial"],
      default: "metric",
      required: true
    }
  },
  { timestamps: true }
);

module.exports = {
  AppSetting: mongoose.model("AppSetting", appSettingSchema)
};
