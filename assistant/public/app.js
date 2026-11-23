const form = document.getElementById("form");
const input = document.getElementById("message");
const chat = document.getElementById("chat");
const send = document.getElementById("send");

function addMessage(text, type) {
  const msg = document.createElement("div");
  msg.className = "msg " + type;
  msg.textContent = text;
  chat.appendChild(msg);
  chat.scrollTop = chat.scrollHeight;
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();

  const value = input.value.trim();
  if (!value) return;

  addMessage(value, "user");
  input.value = "";
  send.disabled = true;

  try {
    const response = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: value })
    });

    const data = await response.json();

    if (!response.ok) throw new Error(data.error);

    addMessage(data.reply, "bot");
  } catch {
    addMessage("برای گفتگو ابتدا باید وارد حساب شوید.", "bot");
  } finally {
    send.disabled = false;
  }
});
