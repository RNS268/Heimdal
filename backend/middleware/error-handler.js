function notFound(req, res) {
  res.status(404).json({
    success: false,
    error: `Route not found: ${req.method} ${req.originalUrl}`
  });
}

function errorHandler(err, req, res, next) {
  if (res.headersSent) return next(err);

  if (err?.code === 11000) {
    return res.status(409).json({
      success: false,
      error: "Duplicate record conflict",
      details: err.keyValue || {}
    });
  }

  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    success: false,
    error: err.message || "Internal server error"
  });
}

module.exports = { notFound, errorHandler };
