const { z } = require("zod");

const deviceTypeEnum = z.enum(["helmet", "heart_rate"]);
const capabilityEnum = z.enum(["crash_detection", "telemetry", "heart_rate"]);
const crashSensitivityEnum = z.enum(["low", "medium", "high"]);
const themeEnum = z.enum(["dark", "light"]);
const unitsEnum = z.enum(["metric", "imperial"]);

const nonEmptyString = z.string().trim().min(1);

const updateDeviceSchema = z.object({
  body: z.object({
    user_id: nonEmptyString.optional(),
    device_id: nonEmptyString,
    name: nonEmptyString,
    type: deviceTypeEnum,
    is_connected: z.boolean(),
    last_seen: z.coerce.date().optional(),
    capabilities: z.array(capabilityEnum).optional()
  }),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

const updateSafetySchema = z.object({
  body: z
    .object({
      user_id: nonEmptyString.optional(),
      crash_sensitivity: crashSensitivityEnum.optional(),
      auto_sos: z.boolean().optional()
    })
    .refine(
      (data) =>
        Object.prototype.hasOwnProperty.call(data, "crash_sensitivity") ||
        Object.prototype.hasOwnProperty.call(data, "auto_sos"),
      "Provide at least one of crash_sensitivity or auto_sos"
    ),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

const emergencyContactSchema = z.object({
  name: nonEmptyString,
  phone: nonEmptyString
});

const updateEmergencyContactsSchema = z.object({
  body: z.object({
    user_id: nonEmptyString.optional(),
    contacts: z.array(emergencyContactSchema).max(5, "Maximum 5 contacts allowed")
  }),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

const updateAppSettingsSchema = z.object({
  body: z
    .object({
      user_id: nonEmptyString.optional(),
      theme: themeEnum.optional(),
      units: unitsEnum.optional()
    })
    .refine(
      (data) =>
        Object.prototype.hasOwnProperty.call(data, "theme") ||
        Object.prototype.hasOwnProperty.call(data, "units"),
      "Provide at least one of theme or units"
    ),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

const normalizeTelemetrySchema = z.object({
  body: z.object({
    payload: z.object({
      speed: z.number().optional(),
      units: unitsEnum.optional()
    }).passthrough()
  }),
  query: z.object({}).optional(),
  params: z.object({}).optional()
});

module.exports = {
  updateDeviceSchema,
  updateSafetySchema,
  updateEmergencyContactsSchema,
  updateAppSettingsSchema,
  normalizeTelemetrySchema
};
