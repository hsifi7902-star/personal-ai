
require("dotenv").config();

const express = require("express");
const path = require("path");
const helmet = require("helmet");
const { askAI } = require("./ai");
const { setupAuth, requireAuth } = require("./auth");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:"],
      connectSrc: ["'self'"],
      objectSrc: ["'none'"],
      baseUri: ["'self'"],
      frameAncestors: ["'none'"]
    }
  }
}));

app.use(express.json({ limit: "1mb" }));

setupAuth(app);

app.use(express.static(path.join(__dirname, "public")));

app.get("/api/health", (req, res) => {
  res.json({ status: "ok" });
});

app.post("/api/chat", requireAuth, async (req, res) => {
  const message = req.body?.message?.trim();

  if (!message) {
    return res.status(400).json({ error: "پیام خالی است." });
  }

  try {
    const reply = await askAI(message);
    res.json({ reply });
  } catch (error) {
    console.error("Chat error:", error.message);
    res.status(500).json({ error: "خطا در پاسخ‌گویی." });
  }
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Personal AI running on port ${PORT}`);
});
