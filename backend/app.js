const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const morgan = require("morgan");
const { settingsRouter } = require("./routes/settings.routes");
const { notFound, errorHandler } = require("./middleware/error-handler");

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: "1mb" }));
app.use(morgan("combined"));

app.get("/health", (req, res) => {
  res.json({ success: true, status: "ok", timestamp: new Date().toISOString() });
});

app.use("/settings", settingsRouter);

app.use(notFound);
app.use(errorHandler);

module.exports = { app };
