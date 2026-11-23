const express = require("express");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.post("/api/chat", (req, res) => {
  const message = req.body?.message?.trim();

  if (!message) {
    return res.status(400).json({ error: "پیام خالی است." });
  }

  res.json({
    received: true,
    reply: "پیامت دریافت شد. اتصال هوش مصنوعی در مرحله بعد فعال می‌شود."
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Personal AI running on port ${PORT}`);
});
