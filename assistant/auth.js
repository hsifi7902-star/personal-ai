
const express = require("express");
const bcrypt = require("bcryptjs");
const session = require("express-session");
const PgSession = require("connect-pg-simple")(session);
const { Pool } = require("pg");
const rateLimit = require("express-rate-limit");

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

function setupAuth(app) {
  if (!process.env.DATABASE_URL || !process.env.SESSION_SECRET) {
    throw new Error("DATABASE_URL and SESSION_SECRET are required");
  }

  app.set("trust proxy", 1);

  app.use(session({
    store: new PgSession({
      pool,
      createTableIfMissing: true
    }),
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      maxAge: 8 * 60 * 60 * 1000
    }
  }));

  const router = express.Router();

  router.post(
    "/login",
    rateLimit({
      windowMs: 15 * 60 * 1000,
      limit: 5
    }),
    async (req, res) => {
      try {
        const { username, password } = req.body;

        if (!username || !password) {
          return res.status(400).json({
            error: "نام کاربری و رمز عبور لازم است."
          });
        }

        const result = await pool.query(
          `SELECT id, username, password_hash, role
           FROM assistant_users
           WHERE username = $1 AND is_active = TRUE`,
          [username]
        );

        const user = result.rows[0];

        if (!user || !(await bcrypt.compare(password, user.password_hash))) {
          return res.status(401).json({
            error: "نام کاربری یا رمز عبور اشتباه است."
          });
        }

        req.session.regenerate((err) => {
          if (err) {
            return res.status(500).json({ error: "خطای ورود." });
          }

          req.session.user = {
            id: user.id,
            username: user.username,
            role: user.role
          };

          res.json({
            success: true,
            user: req.session.user
          });
        });
      } catch (error) {
        console.error("Login error:", error.message);
        res.status(500).json({ error: "خطای داخلی سرور." });
      }
    }
  );

  router.post("/logout", (req, res) => {
    req.session.destroy(() => {
      res.clearCookie("connect.sid");
      res.json({ success: true });
    });
  });

  router.get("/me", (req, res) => {
    if (!req.session.user) {
      return res.status(401).json({ authenticated: false });
    }

    res.json({
      authenticated: true,
      user: req.session.user
    });
  });

  app.use("/api/auth", router);
}

function requireAuth(req, res, next) {
  if (!req.session?.user) {
    return res.status(401).json({ error: "ابتدا وارد شوید." });
  }
  next();
}

function requireManager(req, res, next) {
  if (req.session?.user?.role !== "manager") {
    return res.status(403).json({ error: "دسترسی مجاز نیست." });
  }
  next();
}

module.exports = {
  setupAuth,
  requireAuth,
  requireManager,
  pool
};
