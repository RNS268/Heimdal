const {
  SUPPORTED_DEVICE_TYPES,
  SUPPORTED_CAPABILITIES
} = require("../models/device.model");

const DEFAULT_CAPABILITIES_BY_TYPE = {
  helmet: ["crash_detection", "telemetry"],
  heart_rate: ["heart_rate"]
};

function isSupportedDeviceType(type) {
  return SUPPORTED_DEVICE_TYPES.includes(type);
}

function sanitizeCapabilities(type, capabilities = []) {
  const filtered = capabilities.filter((capability) =>
    SUPPORTED_CAPABILITIES.includes(capability)
  );
  if (filtered.length > 0) return Array.from(new Set(filtered));
  return DEFAULT_CAPABILITIES_BY_TYPE[type] || [];
}

module.exports = {
  isSupportedDeviceType,
  sanitizeCapabilities,
  DEFAULT_CAPABILITIES_BY_TYPE
};
