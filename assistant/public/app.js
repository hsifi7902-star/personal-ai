
const loginPanel = document.getElementById("login");
const chatPanel = document.getElementById("chat");
const usernameInput = document.getElementById("username");
const passwordInput = document.getElementById("password");
const loginButton = document.getElementById("loginButton");
const logoutButton = document.getElementById("logoutButton");
const statusText = document.getElementById("status");
const welcomeText = document.getElementById("welcome");

const form = document.getElementById("form");
const messageInput = document.getElementById("message");
const sendButton = document.getElementById("send");
const messages = document.getElementById("messages");

function showMessage(text, type) {
  const item = document.createElement("div");
  item.className = `msg ${type}`;
  item.textContent = text;
  messages.appendChild(item);
  item.scrollIntoView({ behavior: "smooth", block: "end" });
}

function showLogin() {
  loginPanel.style.display = "block";
  chatPanel.style.display = "none";
}

function showChat(user) {
  loginPanel.style.display = "none";
  chatPanel.style.display = "block";
  welcomeText.textContent = `خوش آمدی ${user.username}`;
}

async function checkLogin() {
  try {
    const response = await fetch("/api/auth/me");
    const data = await response.json();

    if (response.ok && data.authenticated) {
      showChat(data.user);
    } else {
      showLogin();
    }
  } catch {
    showLogin();
    statusText.textContent = "ارتباط با سرور برقرار نشد.";
  }
}

loginButton.addEventListener("click", async () => {
  const username = usernameInput.value.trim();
  const password = passwordInput.value;

  if (!username || !password) {
    statusText.textContent = "نام کاربری و رمز عبور را وارد کن.";
    return;
  }

  loginButton.disabled = true;
  statusText.textContent = "در حال ورود...";

  try {
    const response = await fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, password })
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || "ورود ناموفق بود.");
    }

    passwordInput.value = "";
    statusText.textContent = "";
    showChat(data.user);
  } catch (error) {
    statusText.textContent = error.message;
  } finally {
    loginButton.disabled = false;
  }
});

logoutButton.addEventListener("click", async () => {
  try {
    await fetch("/api/auth/logout", { method: "POST" });
  } finally {
    showLogin();
  }
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const message = messageInput.value.trim();
  if (!message) return;

  showMessage(message, "user");
  messageInput.value = "";
  sendButton.disabled = true;

  try {
    const response = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message })
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || "ارسال پیام ناموفق بود.");
    }

    showMessage(data.reply, "bot");
  } catch (error) {
    showMessage(error.message || "ارتباط با سرور برقرار نشد.", "bot");
  } finally {
    sendButton.disabled = false;
    messageInput.focus();
  }
});

checkLogin();
