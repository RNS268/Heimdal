const { AppSetting } = require("../models/app-setting.model");
const { convertTelemetryPayload } = require("../services/unit-conversion.service");

async function normalizeTelemetryForUser(req, res) {
  const userId = req.userId;
  const payload = req.validated.body.payload || {};

  const app = await AppSetting.findOne({ user_id: userId }).lean();
  const units = app?.units || "metric";

  const converted = convertTelemetryPayload(payload, units);

  return res.json({
    success: true,
    data: {
      user_id: userId,
      units,
      telemetry: converted
    }
  });
}

module.exports = { normalizeTelemetryForUser };
