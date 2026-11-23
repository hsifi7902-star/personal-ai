
require("dotenv").config();

const express = require("express");
const path = require("path");
const helmet = require("helmet");
const { askAI } = require("./ai");
const { setupAuth, requireAuth, pool } = require("./auth");

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

  const userId = String(req.session.user.id);
  const userRole = req.session.user.role;

  let client;
  let transactionOpen = false;

  try {
    client = await pool.connect();

    await client.query("BEGIN");
    transactionOpen = true;

    await client.query(
      `SELECT
        set_config('app.user_id', $1, true),
        set_config('app.user_role', $2, true)`,
      [userId, userRole]
    );

    let result = await client.query(
      `SELECT id
       FROM conversations
       WHERE user_id = $1
         AND is_archived = FALSE
       ORDER BY updated_at DESC
       LIMIT 1`,
      [userId]
    );

    let conversationId;

    if (result.rows.length === 0) {
      result = await client.query(
        `INSERT INTO conversations (user_id, title)
         VALUES ($1, $2)
         RETURNING id`,
        [userId, message.slice(0, 80)]
      );
    }

    conversationId = result.rows[0].id;

    const historyResult = await client.query(
      `SELECT sender_role, message_text
       FROM conversation_messages
       WHERE conversation_id = $1
       ORDER BY created_at DESC
       LIMIT 20`,
      [conversationId]
    );

    const history = historyResult.rows
      .reverse()
      .map(item => ({
        role: item.sender_role,
        content: item.message_text
      }));

    await client.query(
      `INSERT INTO conversation_messages
       (conversation_id, sender_role, message_text)
       VALUES ($1, 'user', $2)`,
      [conversationId, message]
    );

    await client.query(
      `UPDATE conversations
       SET updated_at = NOW()
       WHERE id = $1`,
      [conversationId]
    );

    await client.query("COMMIT");
    transactionOpen = false;

    const reply = await askAI(message, history);

    await client.query("BEGIN");
    transactionOpen = true;

    await client.query(
      `SELECT
        set_config('app.user_id', $1, true),
        set_config('app.user_role', $2, true)`,
      [userId, userRole]
    );

    await client.query(
      `INSERT INTO conversation_messages
       (conversation_id, sender_role, message_text)
       VALUES ($1, 'assistant', $2)`,
      [conversationId, reply]
    );

    await client.query("COMMIT");
    transactionOpen = false;

    res.json({ reply });

  } catch (error) {
    if (client && transactionOpen) {
      await client.query("ROLLBACK").catch(() => {});
    }

    console.error("Chat error:", error.message);

    res.status(500).json({
      error: "در پردازش یا ذخیره پیام مشکلی پیش آمد."
    });

  } finally {
    if (client) client.release();
  }
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Personal AI running on port ${PORT}`);
});
