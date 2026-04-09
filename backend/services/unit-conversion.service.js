const KPH_TO_MPH = 0.621371;

function convertSpeed(value, fromUnits, toUnits) {
  if (fromUnits === toUnits) return value;
  if (fromUnits === "metric" && toUnits === "imperial") {
    return Number((value * KPH_TO_MPH).toFixed(2));
  }
  if (fromUnits === "imperial" && toUnits === "metric") {
    return Number((value / KPH_TO_MPH).toFixed(2));
  }
  return value;
}

function convertTelemetryPayload(payload, toUnits) {
  if (!payload || typeof payload !== "object") return payload;

  const converted = { ...payload };
  if (typeof payload.speed === "number") {
    const sourceUnits = payload.units || "metric";
    converted.speed = convertSpeed(payload.speed, sourceUnits, toUnits);
  }
  converted.units = toUnits;
  return converted;
}

module.exports = {
  convertSpeed,
  convertTelemetryPayload
};
