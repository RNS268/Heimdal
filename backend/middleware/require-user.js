const jwt = require("jsonwebtoken");

function requireUser(req, res, next) {
  const authHeader = req.header("authorization") || "";
  const jwtSecret = process.env.JWT_SECRET;
  let userId = null;

  if (jwtSecret && authHeader.startsWith("Bearer ")) {
    try {
      const token = authHeader.substring("Bearer ".length);
      const decoded = jwt.verify(token, jwtSecret);
      userId = decoded.sub || decoded.user_id || decoded.uid || null;
    } catch (_) {
      return res.status(401).json({
        success: false,
        error: "Invalid bearer token"
      });
    }
  }

  if (!userId) {
    const bodyUserId =
      req.body && typeof req.body === "object" ? req.body.user_id : undefined;
    const queryUserId =
      req.query && typeof req.query === "object" ? req.query.user_id : undefined;
    userId = req.header("x-user-id") || bodyUserId || queryUserId;
  }

  if (!userId) {
    return res.status(400).json({
      success: false,
      error: "user_id is required via x-user-id header, query, or body"
    });
  }

  req.userId = String(userId).trim();
  next();
}

module.exports = { requireUser };
