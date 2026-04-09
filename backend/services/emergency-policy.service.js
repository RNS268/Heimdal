const { SafetySetting } = require("../models/safety-setting.model");

async function canTriggerAutoSOS(userId) {
  const safety = await SafetySetting.findOne({ user_id: userId }).lean();
  if (!safety) return true;
  return safety.auto_sos;
}

module.exports = { canTriggerAutoSOS };
