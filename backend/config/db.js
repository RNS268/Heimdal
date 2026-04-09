const mongoose = require("mongoose");

async function connectDB(uri) {
  mongoose.set("strictQuery", true);
  await mongoose.connect(uri, {
    autoIndex: true,
    maxPoolSize: 20
  });
}

module.exports = { connectDB };
