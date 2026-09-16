import os
import subprocess
import requests
import telebot
import time

TELEGRAM_TOKEN = "8838164031:AAHz-wspgs5ZOmNS9jE_dK-WOoHDcyfgYwY"
ALLOWED_USER_ID = 5558301795
OPENROUTER_API_KEY = "Sk-or-v1-340d146ffabcae835c1b314c2890c1f9eebd85df661ec7b386666823ed83c2bc"

bot = telebot.TeleBot(TELEGRAM_TOKEN)

FREE_MODELS = [
    "meta-llama/llama-3.1-8b-instruct:free",
    "qwen/qwen-2.5-72b-instruct:free",
    "google/gemini-2.0-flash-lite-preview-02-05:free",
    "mistralai/mistral-7b-instruct:free"
]

def execute_adb(command):
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=10)
        return result.stdout if result.stdout else "تم تنفيذ الأمر بنجاح."
    except Exception as e:
        return f"حدث خطأ: {str(e)}"

def clean_adb_command(raw_text):
    if not raw_text:
        return None
    cleaned = raw_text.replace("```bash", "").replace("```", "").strip()
    for line in cleaned.split("\n"):
        line = line.strip()
        if line.startswith("adb"):
            return line
    return cleaned if cleaned.startswith("adb") else None

def ask_llm(user_prompt):
    system_instruction = (
        "أنت مساعد أتمتة هاتف أندرويد. "
        "عندما يطلب المستخدم حركة أو إجراءً على الهاتف، رد عليه بـ أمر ADB Bash فقط المبتدئ بـ adb shell بدون أي شرح أو كلام إضافي."
    )
    
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://telegram.org",
        "X-Title": "TermuxADB"
    }
    
    # الرابط الصافي لـ API
    url = "https://openrouter.ai/api/v1/chat/completions"
    
    for model in FREE_MODELS:
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system_instruction},
                {"role": "user", "content": user_prompt}
            ]
        }
        try:
            print(f"🔄 جاري تجربة النموذج: {model}")
            response = requests.post(url, json=payload, headers=headers, timeout=12)
            data = response.json()
            
            if "choices" in data and len(data["choices"]) > 0:
                raw_cmd = data['choices'][0]['message']['content']
                adb_cmd = clean_adb_command(raw_cmd)
                if adb_cmd:
                    print(f"✅ نجح النموذج ({model}): {adb_cmd}")
                    return adb_cmd
            elif "error" in data:
                print(f"⚠️ خطأ السيرفر ({model}): {data['error'].get('message')}")
        except Exception as e:
            print(f"⚠️ فشل الاتصال بالنموذج {model}: {e}")
            continue
            
    return None

@bot.message_handler(func=lambda message: True)
def handle_message(message):
    if message.from_user.id != ALLOWED_USER_ID:
        bot.reply_to(message, "عذراً، هذا البوت مخصص لصاحب الهاتف فقط.")
        return
    
    user_text = message.text
    bot.reply_to(message, "⏳ جاري المعالجة...")
    
    adb_cmd = ask_llm(user_text)
    
    if adb_cmd:
        output = execute_adb(adb_cmd)
        bot.reply_to(message, f"✅ تم التنفيذ:\n`{adb_cmd}`\n\nالنتيجة:\n{output}", parse_mode="Markdown")
    else:
        bot.reply_to(message, "⚠️ لم ينفذ أي نموذج الأمر، تفقد شاشة Termux.")

print("البوت يعمل الآن بدون أخطاء في الرابط...")

while True:
    try:
        bot.polling(none_stop=True, interval=2, timeout=30)
    except Exception as e:
        print(f"إعادة المحاولة بسبب الاتصال... ({e})")
        time.sleep(5)

