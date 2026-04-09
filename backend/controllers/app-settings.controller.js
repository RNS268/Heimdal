const { AppSetting } = require("../models/app-setting.model");
const { publishSettingsEvent } = require("../services/realtime-publisher.service");

async function getAppSettings(req, res) {
  const userId = req.userId;
  let setting = await AppSetting.findOne({ user_id: userId }).lean();

  if (!setting) {
    setting = {
      user_id: userId,
      theme: "dark",
      units: "metric"
    };
  }

  return res.json({
    success: true,
    data: {
      user_id: userId,
      theme: setting.theme,
      units: setting.units,
      speed_unit_label: setting.units === "metric" ? "km/h" : "mph"
    }
  });
}

async function upsertAppSettings(req, res) {
  const userId = req.userId;
  const body = req.validated.body;

  const existing = await AppSetting.findOne({ user_id: userId }).lean();
  const theme = body.theme || existing?.theme || "dark";
  const units = body.units || existing?.units || "metric";

  const updated = await AppSetting.findOneAndUpdate(
    { user_id: userId },
    {
      $set: {
        user_id: userId,
        theme,
        units
      }
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  ).lean();

  publishSettingsEvent(userId, "app_settings_updated", {
    theme: updated.theme,
    units: updated.units
  });

  return res.json({
    success: true,
    data: {
      user_id: userId,
      theme: updated.theme,
      units: updated.units,
      speed_unit_label: updated.units === "metric" ? "km/h" : "mph"
    }
  });
}

module.exports = {
  getAppSettings,
  upsertAppSettings
};
