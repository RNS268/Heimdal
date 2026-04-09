const { EmergencyContactSetting } = require("../models/emergency-contact.model");
const { normalizePhoneNumber } = require("../services/phone.service");
const { publishSettingsEvent } = require("../services/realtime-publisher.service");

async function getEmergencyContacts(req, res) {
  const userId = req.userId;
  const setting = await EmergencyContactSetting.findOne({ user_id: userId }).lean();

  return res.json({
    success: true,
    data: {
      user_id: userId,
      contacts: setting?.contacts || []
    }
  });
}

async function upsertEmergencyContacts(req, res) {
  const userId = req.userId;
  const inputContacts = req.validated.body.contacts;

  const normalizedContacts = inputContacts.map((contact) => ({
    name: contact.name.trim(),
    phone: normalizePhoneNumber(contact.phone)
  }));

  const dedupeSet = new Set();
  for (const contact of normalizedContacts) {
    const key = contact.phone;
    if (dedupeSet.has(key)) {
      return res.status(400).json({
        success: false,
        error: "Duplicate emergency contact detected"
      });
    }
    dedupeSet.add(key);
  }

  const updated = await EmergencyContactSetting.findOneAndUpdate(
    { user_id: userId },
    { $set: { user_id: userId, contacts: normalizedContacts } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  ).lean();

  publishSettingsEvent(userId, "emergency_contacts_updated", {
    total_contacts: updated.contacts.length
  });

  return res.json({
    success: true,
    data: updated
  });
}

module.exports = {
  getEmergencyContacts,
  upsertEmergencyContacts
};
