git push origin main
cat << 'EOF' > app.py
import os
import time
import threading
import telebot
import google.generativeai as genai
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Idea Generator Bot is Live!"

# إعداد مفتاح جيميني
api_key = os.environ.get("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel('gemini-1.5-pro')

# توكن البوت
TELEGRAM_TOKEN = "8804142794:AAHpJN3M1KGDVrM34CMc88VFE5siEFnO_cg"
bot = telebot.TeleBot(TELEGRAM_TOKEN)

@bot.message_handler(commands=['start', 'help'])
def send_welcome(message):
    print(f" Received /start from: {message.chat.id}")
    welcome_msg = (
        "👋 أهلاً بك في بوت 'مهندس المشاريع الذكي'!\n\n"
        "أرسل لي اسم أي مجال (مثال: التجارة، التعليم، الطب، الألعاب)\n"
        "أو أرسل كلمة 'مفاجأة' لأقترح عليك مشروعاً برمجياً عبقرياً ودقيقاً من اختياري."
    )
    bot.reply_to(message, welcome_msg)

@bot.message_handler(func=lambda message: True)
def generate_idea_for_telegram(message):
    print(f" Generating idea for: {message.text}")
    user_input = message.text.strip()
    target_niche = "مجال مبتكر وعشوائي من اختيارك، فاجئني!" if user_input == 'مفاجأة' else user_input
    
    wait_msg = bot.reply_to(message, "⏳ جاري عصرنة الدماغ الاصطناعي لابتكار فكرة مشروع دقيقة... لحظات.")
    
    prompt = f"""
    أنت كبير مهندسي البرمجيات ومستشار ابتكار مشاريع ناشئة.
    مهمتك ابتكار فكرة تطبيق أو مشروع برمجي ذكي جداً ومبتكر في مجال: {target_niche}.
    
    أريد فكرة دقيقة، غنية في محتواها، ومشبعة من حيث القابلية للتطبيق التقني.
    
    قم بهيكلة الإجابة كالتالي:
    💡 اسم المشروع:
    🎯 المشكلة الجوهرية:
    🚀 قلب الفكرة وعبقريتها:
    🧩 الميزات الأساسية:
    🛠️ الترسانة التقنية (Tech Stack):
    📈 نموذج العمل والربح:
    🛤️ الخطوة الأولى للبدء:
    """
    
    try:
        response = model.generate_content(prompt)
        bot.edit_message_text(chat_id=message.chat.id, message_id=wait_msg.message_id, text=response.text)
    except Exception as e:
        print(f"❌ Error: {e}")
        bot.edit_message_text(chat_id=message.chat.id, message_id=wait_msg.message_id, text=f"❌ حدث خطأ: {e}")

def run_bot():
    print("🤖 Clearing old webhooks...")
    try:
        bot.remove_webhook()
    except Exception as e:
        print(f"Webhook error: {e}")
    time.sleep(1)
    print("🤖 Starting Telegram polling...")
    bot.infinity_polling(timeout=60, long_polling_timeout=60)

if __name__ == "__main__":
    # تشغيل عملية الاستماع للبوت في مسار محمي
    bot_thread = threading.Thread(target=run_bot)
    bot_thread.start()
    
    # محاولة تشغيل Flask، وفي حال حجز المنفذ يستمر البوت دون توقف
    try:
        port = int(os.environ.get('PORT', 10000))
        app.run(host='0.0.0.0', port=port)
    except Exception as e:
        print(f"⚠️ Port conflict ignored: {e}. Bot will remain running.")
        bot_thread.join()
EOF

git add app.py
git commit -m "Fix port collision crash and keep bot thread alive"
git push origin main
cat << 'EOF' > app.py
import os
import time
import threading
import telebot
import google.generativeai as genai
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Idea Generator Bot is Live!"

# إعداد مفتاح جيميني
api_key = os.environ.get("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)

TELEGRAM_TOKEN = "8804142794:AAHpJN3M1KGDVrM34CMc88VFE5siEFnO_cg"
bot = telebot.TeleBot(TELEGRAM_TOKEN)

def generate_with_fallback(prompt):
    """يبحث عن أسرع وأحدث نموذج متاح ويولد الإجابة فوراً"""
    # 1. التجربة عبر استعلام النماذج المتاحة من جوجل
    try:
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                try:
                    model = genai.GenerativeModel(m.name)
                    res = model.generate_content(prompt)
                    if res and res.text:
                        return res.text
                except Exception:
                    continue
    except Exception as e:
        print(f"List models check failed: {e}")

    # 2. خطة بديلة في حال تعذر الاستعلام: تجربة القائمة المباشرة
    candidate_models = [
        'gemini-2.5-flash',
        'gemini-2.0-flash',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
        'gemini-pro'
    ]
    
    last_error = None
    for model_name in candidate_models:
        try:
            model = genai.GenerativeModel(model_name)
            res = model.generate_content(prompt)
            if res and res.text:
                return res.text
        except Exception as e:
            last_error = e
            continue
            
    raise Exception(f"تعذر الاتصال بجميع النماذج: {last_error}")

@bot.message_handler(commands=['start', 'help'])
def send_welcome(message):
    print(f"Received /start from: {message.chat.id}")
    welcome_msg = (
        "👋 أهلاً بك في بوت 'مهندس المشاريع الذكي'!\n\n"
        "أرسل لي اسم أي مجال (مثال: التجارة، التعليم، الطب، الألعاب)\n"
        "أو أرسل كلمة 'مفاجأة' لأقترح عليك مشروعاً برمجياً عبقرياً ودقيقاً من اختياري."
    )
    bot.reply_to(message, welcome_msg)

@bot.message_handler(func=lambda message: True)
def generate_idea_for_telegram(message):
    print(f"Generating idea for: {message.text}")
    user_input = message.text.strip()
    target_niche = "مجال مبتكر وعشوائي من اختيارك، فاجئني!" if user_input == 'مفاجأة' else user_input
    
    wait_msg = bot.reply_to(message, "⏳ جاري عصرنة الدماغ الاصطناعي لابتكار فكرة مشروع دقيقة... لحظات.")
    
    prompt = f"""
    أنت كبير مهندسي البرمجيات ومستشار ابتكار مشاريع ناشئة.
    مهمتك ابتكار فكرة تطبيق أو مشروع برمجي ذكي جداً ومبتكر في مجال: {target_niche}.
    
    أريد فكرة دقيقة، غنية في محتواها، ومشبعة من حيث القابلية للتطبيق التقني.
    
    قم بهيكلة الإجابة كالتالي:
    💡 اسم المشروع:
    🎯 المشكلة الجوهرية:
    🚀 قلب الفكرة وعبقريتها:
    🧩 الميزات الأساسية:
    🛠️ الترسانة التقنية (Tech Stack):
    📈 نموذج العمل والربح:
    🛤️ الخطوة الأولى للبدء:
    """
    
    try:
        response_text = generate_with_fallback(prompt)
        bot.edit_message_text(chat_id=message.chat.id, message_id=wait_msg.message_id, text=response_text)
    except Exception as e:
        print(f"❌ Error: {e}")
        bot.edit_message_text(chat_id=message.chat.id, message_id=wait_msg.message_id, text=f"❌ حدث خطأ: {e}")

def run_bot():
    print("🤖 Clearing old webhooks...")
    try:
        bot.remove_webhook()
    except Exception as e:
        print(f"Webhook error: {e}")
    time.sleep(1)
    print("🤖 Starting Telegram polling...")
    bot.infinity_polling(timeout=60, long_polling_timeout=60)

if __name__ == "__main__":
    bot_thread = threading.Thread(target=run_bot)
    bot_thread.start()
    
    try:
        port = int(os.environ.get('PORT', 10000))
        app.run(host='0.0.0.0', port=port)
    except Exception as e:
        print(f"⚠️ Port conflict ignored: {e}. Bot will remain running.")
        bot_thread.join()
EOF

git add app.py
git commit -m "Add auto-fallback model resolution for Gemini API"
git push origin main
cat << 'EOF' > app.py
import os
import time
import threading
import telebot
import google.generativeai as genai
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Idea Generator Bot is Live!"

# إعداد مفتاح جيميني
api_key = os.environ.get("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)

TELEGRAM_TOKEN = "8804142794:AAHpJN3M1KGDVrM34CMc88VFE5siEFnO_cg"
bot = telebot.TeleBot(TELEGRAM_TOKEN)

def send_large_text(chat_id, text, wait_msg_id=None):
    """تقسيم النصوص الطويلة وإرسالها على رسائل متتالية تجنباً لخطأ MESSAGE_TOO_LONG"""
    max_length = 4000
    chunks = []
    
    while len(text) > max_length:
        split_pos = text.rfind('\n', 0, max_length)
        if split_pos == -1:
            split_pos = max_length
        chunks.append(text[:split_pos])
        text = text[split_pos:].lstrip()
    if text:
        chunks.append(text)
        
    for i, chunk in enumerate(chunks):
        if i == 0 and wait_msg_id:
            bot.edit_message_text(chat_id=chat_id, message_id=wait_msg_id, text=chunk)
        else:
            bot.send_message(chat_id=chat_id, text=chunk)

def generate_with_fallback(prompt):
    """البحث عن أفضل نموذج متاح وتوليد الإجابة"""
    try:
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                try:
                    model = genai.GenerativeModel(m.name)
                    res = model.generate_content(prompt)
                    if res and res.text:
                        return res.text
                except Exception:
                    continue
    except Exception as e:
        print(f"List models check failed: {e}")

    candidate_models = [
        'gemini-2.5-flash',
        'gemini-2.0-flash',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
        'gemini-pro'
    ]
    
    last_error = None
    for model_name in candidate_models:
        try:
            model = genai.GenerativeModel(model_name)
            res = model.generate_content(prompt)
            if res and res.text:
                return res.text
        except Exception as e:
            last_error = e
            continue
            
    raise Exception(f"تعذر الاتصال بجميع النماذج: {last_error}")

@bot.message_handler(commands=['start', 'help'])
def send_welcome(message):
    welcome_msg = (
        "👋 أهلاً بك في بوت 'مهندس المشاريع الذكي'!\n\n"
        "أرسل لي اسم أي مجال (مثال: التجارة، التعليم، الطب، الألعاب)\n"
        "أو أرسل كلمة 'مفاجأة' لأقترح عليك مشروعاً برمجياً عبقرياً ودقيقاً من اختياري."
    )
    bot.reply_to(message, welcome_msg)

@bot.message_handler(func=lambda message: True)
def generate_idea_for_telegram(message):
    user_input = message.text.strip()
    target_niche = "مجال مبتكر وعشوائي من اختيارك، فاجئني!" if user_input == 'مفاجأة' else user_input
    
    wait_msg = bot.reply_to(message, "⏳ جاري عصرنة الدماغ الاصطناعي لابتكار فكرة مشروع دقيقة... لحظات.")
    
    prompt = f"""
    أنت كبير مهندسي البرمجيات ومستشار ابتكار مشاريع ناشئة.
    مهمتك ابتكار فكرة تطبيق أو مشروع برمجي ذكي جداً ومبتكر في مجال: {target_niche}.
    
    أريد فكرة دقيقة، غنية في محتواها، ومشبعة من حيث القابلية للتطبيق التقني.
    
    قم بهيكلة الإجابة كالتالي:
    💡 اسم المشروع:
    🎯 المشكلة الجوهرية:
    🚀 قلب الفكرة وعبقريتها:
    🧩 الميزات الأساسية:
    🛠️ الترسانة التقنية (Tech Stack):
    📈 نموذج العمل والربح:
        🛤️ الخطوة الأولى للبدء:
    """
    
    try:
        response_text = generate_with_fallback(prompt)
        send_large_text(message.chat.id, response_text, wait_msg.message_id)
    except Exception as e:
        print(f"❌ Error: {e}")
        bot.edit_message_text(chat_id=message.chat.id, message_id=wait_msg.message_id, text=f"❌ حدث خطأ: {e}")

def run_bot():
    try:
        bot.remove_webhook()
    except Exception:
        pass
    time.sleep(1)
    bot.infinity_polling(timeout=60, long_polling_timeout=60)

if __name__ == "__main__":
    bot_thread = threading.Thread(target=run_bot)
    bot_thread.start()
    
    try:
        port = int(os.environ.get('PORT', 10000))
        app.run(host='0.0.0.0', port=port)
    except Exception as e:
        bot_thread.join()
EOF

git add app.py
git commit -m "Fix Telegram MESSAGE_TOO_LONG error with text chunking"
git push origin main
python -c '
import urllib.request
import json

url = "https://api.cron-job.org/jobs"
api_key = "KD81VqZ6zYj8hCEbVplnx2eHec2Atox9cT0Fpitu8rU="
bot_url = "https://telegram-ai-bot-1-ufx5.onrender.com"

payload = {
    "job": {
        "url": bot_url,
        "title": "Render Bot KeepAlive",
        "enabled": True,
        "saveResponses": True,
        "schedule": {
            "timezone": "UTC",
            "expiresAt": 0,
            "hours": [-1],
            "mdays": [-1],
            "minutes": [0, 10, 20, 30, 40, 50],
            "months": [-1],
            "wdays": [-1]
        }
    }
}

req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    },
    method="PUT"
)

try:
    with urllib.request.urlopen(req) as response:
        res_data = json.loads(response.read().decode())
        print("\n✅ تم تسجيل المهمة بنجاح 100% على السحابة!")
        print(f"📌 Job ID: {res_data.get(\"jobId\", \"OK\")}")
        print("🚀 البوت سيعمل الآن 24/7 بدون توقف، يمكنك إغلاق Termux نهائياً.")
except Exception as e:
    print(f"\n❌ حدث خطأ أثناء الاتصال: {e}")
'
python -c '
import urllib.request
import json

url = "https://api.cron-job.org/jobs"
api_key = "KD81VqZ6zYj8hCEbVplnx2eHec2Atox9cT0Fpitu8rU="
bot_url = "https://telegram-ai-bot-1-ufx5.onrender.com"

payload = {
    "job": {
        "url": bot_url,
        "title": "Render Bot KeepAlive",
        "enabled": True,
        "saveResponses": True,
        "schedule": {
            "timezone": "UTC",
            "expiresAt": 0,
            "hours": [-1],
            "mdays": [-1],
            "minutes": [0, 10, 20, 30, 40, 50],
            "months": [-1],
            "wdays": [-1]
        }
    }
}

req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    },
    method="PUT"
)

try:
    with urllib.request.urlopen(req) as response:
        res_data = json.loads(response.read().decode())
        job_id = res_data.get("jobId", "OK")
        print("\n✅ تم تسجيل المهمة بنجاح 100% على السحابة!")
        print(f"📌 Job ID: {job_id}")
        print("🚀 البوت سيعمل الآن 24/7 بدون توقف، يمكنك إغلاق Termux نهائياً.")
except Exception as e:
    print(f"\n❌ حدث خطأ أثناء الاتصال: {e}")
'
python -c '
import urllib.request
import json

service_id = "srv-dakg1tgu01pc73f19vl0"
api_key = input("🔑 ألصق Render API Key واضغط Enter: ").strip()

url = f"https://api.render.com/v1/services/{service_id}/deploys"
req = urllib.request.Request(
    url,
    data=b"{}",
    headers={
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode())
        print("\n✅ تم إرسال أمر إعادة التشغيل (Redeploy) بنجاح!")
        print(f"📌 Deploy ID: {res.get(\"id\", \"OK\")}")
        print("⏳ انتظر حوالي 60 ثانية ثم جرب إرسال رسالة للبوت في تلجرام.")
except Exception as e:
    print(f"\n❌ حدث خطأ: {e}")
'
cat << 'EOF' > redeploy.sh
#!/bin/bash
echo -n "🔑 ألصق Render API Key هنا واضغط Enter: "
read -r API_KEY

echo -e "\n🚀 جاري إرسال أمر إعادة التشغيل لـ Render..."

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "https://api.render.com/v1/services/srv-dakg1tgu01pc73f19vl0/deploys" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json")

if [ "$STATUS" -eq 201 ] || [ "$STATUS" -eq 200 ]; then
    echo -e "\n✅ تم إرسال أمر إعادة التشغيل بنجاح!"
    echo "⏳ انتظر 60 ثانية ثم جرب إرسال رسالة للبوت في تلجرام."
else
    echo -e "\n❌ فشل الاتصال، رمز الاستجابة: $STATUS"
    echo "تأكد من نسخت الـ API Key بشكل صحيح من حسابك في Render."
fi
EOF

chmod +x redeploy.sh && ./redeploy.sh
