const { Device } = require("../models/device.model");
const { DeviceCommand } = require("../models/device-command.model");
const { publishSettingsEvent } = require("./realtime-publisher.service");

const CRASH_SENSITIVITY_THRESHOLDS = {
  low: {
    g_force_threshold: 6.5,
    sensitivity_factor: 0.35
  },
  medium: {
    g_force_threshold: 5.0,
    sensitivity_factor: 0.6
  },
  high: {
    g_force_threshold: 3.8,
    sensitivity_factor: 0.9
  }
};

function getThresholdForSensitivity(crashSensitivity) {
  return CRASH_SENSITIVITY_THRESHOLDS[crashSensitivity];
}

async function propagateCrashSensitivityChange(userId, crashSensitivity) {
  const connectedHelmet = await Device.findOne({
    user_id: userId,
    type: "helmet",
    is_connected: true
  }).lean();

  if (!connectedHelmet) return { propagated: false, reason: "no_connected_helmet" };

  const thresholds = getThresholdForSensitivity(crashSensitivity);
  const command = await DeviceCommand.create({
    user_id: userId,
    device_id: connectedHelmet.device_id,
    command_type: "update_crash_sensitivity",
    payload: { crash_sensitivity: crashSensitivity, thresholds },
    status: "pending"
  });

  publishSettingsEvent(userId, "crash_sensitivity_changed", {
    command_id: command._id.toString(),
    device_id: connectedHelmet.device_id,
    crash_sensitivity: crashSensitivity,
    thresholds
  });

  return { propagated: true, device_id: connectedHelmet.device_id };
}

module.exports = {
  CRASH_SENSITIVITY_THRESHOLDS,
  getThresholdForSensitivity,
  propagateCrashSensitivityChange
};
