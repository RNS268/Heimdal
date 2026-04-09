const { parsePhoneNumberFromString } = require("libphonenumber-js");

function normalizePhoneNumber(input, defaultCountry = "US") {
  const parsed = parsePhoneNumberFromString(input, defaultCountry);
  if (!parsed || !parsed.isValid()) {
    throw new Error("Invalid phone number");
  }
  return parsed.number;
}

module.exports = { normalizePhoneNumber };
