const { SafetySetting } = require("../models/safety-setting.model");
const {
  getThresholdForSensitivity,
  propagateCrashSensitivityChange
} = require("../services/safety-config.service");
const { canTriggerAutoSOS } = require("../services/emergency-policy.service");
const { publishSettingsEvent } = require("../services/realtime-publisher.service");

async function getSafetySettings(req, res) {
  const userId = req.userId;
  let setting = await SafetySetting.findOne({ user_id: userId }).lean();

  if (!setting) {
    setting = {
      user_id: userId,
      crash_sensitivity: "medium",
      auto_sos: true
    };
  }

  return res.json({
    success: true,
    data: {
      user_id: userId,
      crash_sensitivity: setting.crash_sensitivity,
      auto_sos: setting.auto_sos,
      thresholds: getThresholdForSensitivity(setting.crash_sensitivity)
    }
  });
}

async function upsertSafetySettings(req, res) {
  const userId = req.userId;
  const body = req.validated.body;

  const existing = await SafetySetting.findOne({ user_id: userId }).lean();
  const nextSensitivity = body.crash_sensitivity || existing?.crash_sensitivity || "medium";
  const nextAutoSos =
    typeof body.auto_sos === "boolean" ? body.auto_sos : existing?.auto_sos ?? true;

  const updated = await SafetySetting.findOneAndUpdate(
    { user_id: userId },
    {
      $set: {
        user_id: userId,
        crash_sensitivity: nextSensitivity,
        auto_sos: nextAutoSos
      }
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  ).lean();

  let propagation = null;
  if (body.crash_sensitivity && body.crash_sensitivity !== existing?.crash_sensitivity) {
    propagation = await propagateCrashSensitivityChange(userId, body.crash_sensitivity);
  }

  publishSettingsEvent(userId, "safety_settings_updated", {
    crash_sensitivity: updated.crash_sensitivity,
    auto_sos: updated.auto_sos
  });

  return res.json({
    success: true,
    data: {
      user_id: userId,
      crash_sensitivity: updated.crash_sensitivity,
      auto_sos: updated.auto_sos,
      thresholds: getThresholdForSensitivity(updated.crash_sensitivity),
      propagation
    }
  });
}

async function getAutoSosPolicy(req, res) {
  const userId = req.userId;
  const allowed = await canTriggerAutoSOS(userId);

  return res.json({
    success: true,
    data: {
      user_id: userId,
      auto_sos_enabled: allowed
    }
  });
}

module.exports = {
  getSafetySettings,
  upsertSafetySettings,
  getAutoSosPolicy
};
