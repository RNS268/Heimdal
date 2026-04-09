const express = require("express");
const { asyncHandler } = require("../middleware/async-handler");
const { requireUser } = require("../middleware/require-user");
const { validate } = require("../middleware/validate");
const {
  updateDeviceSchema,
  updateSafetySchema,
  updateEmergencyContactsSchema,
  updateAppSettingsSchema,
  normalizeTelemetrySchema
} = require("../middleware/settings.schemas");
const {
  getConnectedSupportedDevices,
  upsertDeviceStatus
} = require("../controllers/device.controller");
const {
  getSafetySettings,
  upsertSafetySettings,
  getAutoSosPolicy
} = require("../controllers/safety.controller");
const {
  getEmergencyContacts,
  upsertEmergencyContacts
} = require("../controllers/emergency-contacts.controller");
const {
  getAppSettings,
  upsertAppSettings
} = require("../controllers/app-settings.controller");
const { normalizeTelemetryForUser } = require("../controllers/telemetry.controller");

const router = express.Router();

router.use(requireUser);

router.get("/devices", asyncHandler(getConnectedSupportedDevices));
router.post(
  "/devices/update",
  validate(updateDeviceSchema),
  asyncHandler(upsertDeviceStatus)
);

router.get("/safety", asyncHandler(getSafetySettings));
router.post("/safety", validate(updateSafetySchema), asyncHandler(upsertSafetySettings));
router.get("/safety/auto-sos-policy", asyncHandler(getAutoSosPolicy));

router.get("/emergency-contacts", asyncHandler(getEmergencyContacts));
router.post(
  "/emergency-contacts",
  validate(updateEmergencyContactsSchema),
  asyncHandler(upsertEmergencyContacts)
);

router.get("/app", asyncHandler(getAppSettings));
router.post("/app", validate(updateAppSettingsSchema), asyncHandler(upsertAppSettings));
router.post(
  "/telemetry/normalize",
  validate(normalizeTelemetrySchema),
  asyncHandler(normalizeTelemetryForUser)
);

module.exports = { settingsRouter: router };
