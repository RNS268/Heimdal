const { EmergencyContactSetting } = require("../models/emergency-contact.model");
const { normalizePhoneNumber } = require("../services/phone.service");
const { publishSettingsEvent } = require("../services/realtime-publisher.service");

async function getEmergencyContacts(req, res) {
  const userId = req.userId;
  const setting = await EmergencyContactSetting.findOne({ user_id: userId }).lean();
  const contacts = setting?.contacts || [];

  return res.json({
    success: true,
    data: {
      user_id: userId,
      contacts,
      total_contacts: contacts.length,
      fallback_emergency_number: "112",
      using_fallback: contacts.length === 0
    }
  });
}

async function upsertEmergencyContacts(req, res) {
  const userId = req.userId;
  const inputContacts = req.validated.body.contacts;

  let normalizedContacts;
  try {
    normalizedContacts = inputContacts.map((contact) => ({
      name: contact.name.trim(),
      phone: normalizePhoneNumber(contact.phone)
    }));
  } catch (_) {
    return res.status(400).json({
      success: false,
      error: "One or more phone numbers are invalid"
    });
  }

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
    data: {
      user_id: userId,
      contacts: updated.contacts,
      total_contacts: updated.contacts.length,
      fallback_emergency_number: "112",
      using_fallback: updated.contacts.length === 0
    }
  });
}

module.exports = {
  getEmergencyContacts,
  upsertEmergencyContacts
};
