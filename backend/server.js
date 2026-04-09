require("dotenv").config();
const { app } = require("./app");
const { connectDB } = require("./config/db");

const PORT = Number(process.env.PORT || 4000);
const MONGODB_URI = process.env.MONGODB_URI;

async function start() {
  if (!MONGODB_URI) {
    throw new Error("Missing MONGODB_URI in environment");
  }

  await connectDB(MONGODB_URI);
  app.listen(PORT, () => {
    console.log(`Settings backend running on port ${PORT}`);
  });
}

start().catch((error) => {
  console.error("Failed to start server:", error);
  process.exit(1);
});
