
const express = require("express");
const path = require("path");
const { askAI } = require("./ai");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json({ limit: "1mb" }));
app.use(express.static(path.join(__dirname, "public")));

app.get("/api/health", (req, res) => {
  res.json({ status: "ok" });
});

app.post("/api/chat", async (req, res) => {
  const message = req.body?.message?.trim();

  if (!message) {
    return res.status(400).json({ error: "پیام خالی است." });
  }

  try {
    const reply = await askAI(message);
    res.json({ reply });
  } catch {
    res.status(500).json({ error: "خطا در پاسخ‌گویی." });
  }
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Personal AI running on port ${PORT}`);
});
