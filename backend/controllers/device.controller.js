const { Device } = require("../models/device.model");
const { sanitizeCapabilities } = require("../services/device-support.service");
const { publishSettingsEvent } = require("../services/realtime-publisher.service");

async function getConnectedSupportedDevices(req, res) {
  const devices = await Device.find({
    user_id: req.userId,
    is_connected: true,
    capabilities: { $exists: true, $ne: [] },
    type: { $in: ["helmet", "heart_rate"] }
  })
    .sort({ last_seen: -1 })
    .lean();

  return res.json({
    success: true,
    data: devices
  });
}

async function upsertDeviceStatus(req, res) {
  const payload = req.validated.body;
  const userId = req.userId;

  const capabilities = sanitizeCapabilities(payload.type, payload.capabilities || []);

  if (payload.type === "helmet" && payload.is_connected === true) {
    await Device.updateMany(
      {
        user_id: userId,
        type: "helmet",
        device_id: { $ne: payload.device_id },
        is_connected: true
      },
      {
        $set: {
          is_connected: false,
          last_seen: new Date()
        }
      }
    );
  }

  let updated;
  try {
    updated = await Device.findOneAndUpdate(
      { user_id: userId, device_id: payload.device_id },
      {
        $set: {
          user_id: userId,
          device_id: payload.device_id,
          name: payload.name,
          type: payload.type,
          is_connected: payload.is_connected,
          last_seen: payload.last_seen || new Date(),
          capabilities
        }
      },
      { upsert: true, new: true, runValidators: true, setDefaultsOnInsert: true }
    ).lean();
  } catch (error) {
    if (error?.code === 11000 && payload.type === "helmet" && payload.is_connected) {
      return res.status(409).json({
        success: false,
        error: "Another helmet is already active for this user"
      });
    }
    throw error;
  }

  publishSettingsEvent(userId, "device_status_updated", {
    device_id: updated.device_id,
    is_connected: updated.is_connected,
    type: updated.type
  });

  return res.json({
    success: true,
    data: updated
  });
}

module.exports = {
  getConnectedSupportedDevices,
  upsertDeviceStatus
};
