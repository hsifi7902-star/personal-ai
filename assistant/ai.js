
async function askAI(message, history = []) {
  const apiKey = process.env.AI_API_KEY;
  const baseURL = process.env.AI_BASE_URL;
  const model = process.env.AI_MODEL;

  if (!apiKey || !baseURL || !model) {
    return "اتصال هوش مصنوعی هنوز تنظیم نشده است.";
  }

  try {
    const response = await fetch(
      `${baseURL.replace(/\/+$/, "")}/chat/completions`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: "system",
              content: "تو دستیار هوشمند مدیریت کسب‌وکار هستی. فارسی، دقیق و کوتاه پاسخ بده."
            },
            ...history,
            { role: "user", content: message }
          ]
        })
      }
    );

    if (!response.ok) {
      throw new Error(`AI API error: ${response.status}`);
    }

    const data = await response.json();
    return data.choices?.[0]?.message?.content ||
      "پاسخی از هوش مصنوعی دریافت نشد.";

  } catch (error) {
    console.error("AI error:", error.message);
    return "در ارتباط با هوش مصنوعی مشکلی پیش آمد.";
  }
}

module.exports = { askAI };
