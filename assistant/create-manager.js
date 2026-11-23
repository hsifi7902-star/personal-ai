
require("dotenv").config();

const bcrypt = require("bcryptjs");
const { Pool } = require("pg");

async function main() {
  const { DATABASE_URL, MANAGER_USERNAME, MANAGER_PASSWORD } = process.env;

  if (!DATABASE_URL || !MANAGER_USERNAME || !MANAGER_PASSWORD) {
    throw new Error("تنظیمات اتصال و اطلاعات مدیر کامل نیست.");
  }

  if (MANAGER_PASSWORD.length < 12) {
    throw new Error("رمز مدیر باید حداقل ۱۲ کاراکتر باشد.");
  }

  const pool = new Pool({ connectionString: DATABASE_URL });

  try {
    const passwordHash = await bcrypt.hash(MANAGER_PASSWORD, 12);

    await pool.query(
      `INSERT INTO assistant_users (username, password_hash, role)
       VALUES ($1, $2, 'manager')
       ON CONFLICT (username) DO NOTHING`,
      [MANAGER_USERNAME, passwordHash]
    );

    console.log("بررسی حساب مدیر انجام شد.");
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
