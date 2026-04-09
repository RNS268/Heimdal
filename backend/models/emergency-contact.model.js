const mongoose = require("mongoose");

const contactSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true }
  },
  { _id: false }
);

const emergencyContactSettingSchema = new mongoose.Schema(
  {
    user_id: { type: String, required: true, unique: true, trim: true },
    contacts: { type: [contactSchema], default: [] }
  },
  { timestamps: true }
);

module.exports = {
  EmergencyContactSetting: mongoose.model(
    "EmergencyContactSetting",
    emergencyContactSettingSchema
  )
};
