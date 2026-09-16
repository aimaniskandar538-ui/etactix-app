import os
import sys
import time
import re
import socket
import requests
from dotenv import load_dotenv
from bs4 import BeautifulSoup

# إجبار الاتصال على IPv4 لمنع خطأ ConnectionAbortedError(103)
old_getaddrinfo = socket.getaddrinfo
def force_ipv4_getaddrinfo(*args, **kwargs):
    responses = old_getaddrinfo(*args, **kwargs)
    return [response for response in responses if response[0] == socket.AF_INET]
socket.getaddrinfo = force_ipv4_getaddrinfo

load_dotenv()

raw_key = os.getenv("OPENAI_API_KEY", "")
key_match = re.search(r'sk-or-v1-[a-zA-Z0-9_-]+', raw_key)
API_KEY = key_match.group(0) if key_match else raw_key.strip().strip("[]'\"")

API_BASE = os.getenv("OPENAI_API_BASE", "https://openrouter.ai/api/v1").strip().strip("[]'\"")

raw_token = os.getenv("TELEGRAM_BOT_TOKEN", "")
token_match = re.search(r'\d+:[A-Za-z0-9_-]+', raw_token)
TELEGRAM_BOT_TOKEN = token_match.group(0) if token_match else ""

raw_chat_id = os.getenv("TELEGRAM_CHAT_ID", "")
chat_match = re.search(r'-?\d+', raw_chat_id)
TELEGRAM_CHAT_ID = chat_match.group(0) if chat_match else ""

TG_HOST = "api.telegram.org"
TG_BASE_URL = f"https://{TG_HOST}/bot{TELEGRAM_BOT_TOKEN}"

def get_dynamic_free_models():
    """جلب النماذج المجانية الشغالة حالياً ومباشرة من API الخادم"""
    url = "https://openrouter.ai/api/v1/models"
    fallback_models = [
        "openrouter/auto",
        "deepseek/deepseek-r1:free",
        "meta-llama/llama-3.3-70b-instruct:free",
        "qwen/qwen-2.5-coder-32b-instruct:free"
    ]
    try:
        res = requests.get(url, timeout=10)
        if res.status_code == 200:
            data = res.json().get("data", [])
            free_models = []
            for item in data:
                m_id = item.get("id", "")
                pricing = item.get("pricing", {})
                if m_id.endswith(":free") or (pricing.get("prompt") == "0" and pricing.get("completion") == "0"):
                    free_models.append(m_id)
            if free_models:
                print(f"[+] تم جلب {len(free_models)} نموذج مجاني نشط أوتوماتيكياً.")
                return free_models
    except Exception as e:
        print(f"[!] تعذر جلب القائمة الديناميكية: {e}")
    
    return fallback_models

def send_telegram(message: str):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    url = f"{TG_BASE_URL}/sendMessage"
    for i in range(0, len(message), 4000):
        chunk = message[i:i+4000]
        payload = {"chat_id": TELEGRAM_CHAT_ID, "text": chunk}
        try:
            requests.post(url, json=payload, timeout=15)
        except Exception:
            pass

def send_telegram_file(file_path: str, caption: str = ""):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    url = f"{TG_BASE_URL}/sendDocument"
    try:
        with open(file_path, "rb") as f:
            files = {"document": f}
            data = {"chat_id": TELEGRAM_CHAT_ID, "caption": caption}
            requests.post(url, data=data, files=files, timeout=30)
    except Exception as e:
        print(f"[!] فشل إرسال الملف: {e}")

def web_search(query: str) -> str:
    url = "https://html.duckduckgo.com/html/"
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    try:
        response = requests.post(url, data={'q': query}, headers=headers, timeout=12)
        soup = BeautifulSoup(response.text, 'html.parser')
        results = []
        for result in soup.find_all('div', class_='result__body', limit=3):
            title = result.find('a', class_='result__a')
            snippet = result.find('a', class_='result__snippet')
            if title and snippet:
                results.append(f"العنوان: {title.get_text(strip=True)}\nالمحتوى: {snippet.get_text(strip=True)}")
        return "\n\n".join(results) if results else "لم يتم العثور على نتائج مباشرة."
    except Exception as e:
        return "تم تجاوز البحث بسبب الشبكة."

def call_llm(system_prompt: str, user_prompt: str):
    if not API_KEY or not API_KEY.startswith("sk-or-v1-"):
        return "خطأ: مفتاح OpenRouter API مفقود أو غير صحيح.", None

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://openrouter.ai",
        "X-Title": "Termux Agent"
    }
    
    free_models = get_dynamic_free_models()
    last_error = ""

    for model in free_models:
        print(f"[+] تجربة الاتصال بالنموذج: {model} ...")
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ]
        }
        try:
            response = requests.post(f"{API_BASE}/chat/completions", json=payload, headers=headers, timeout=35)
            if response.status_code == 200:
                res_json = response.json()
                content = res_json['choices'][0]['message']['content']
                print(f"[✓] نجح الاتصال عبر: {model}")
                return content, model
            else:
                last_error = f"رمز {response.status_code}: {response.text[:80]}"
                print(f"[!] فشل {model} -> {last_error}")
        except Exception as e:
            last_error = str(e)
            print(f"[!] خطأ مع {model}: {e}")
            time.sleep(1)
            
    return f"خطأ: تعذر الاتصال بجميع النماذج المجانية ({len(free_models)} نموذج). التفاصيل: {last_error}", None

def process_goal(goal: str):
    print(f"\n[+] معالجة: {goal}")
    send_telegram(f"⏳ جاري الفحص التلقائي للنماذج المجانية لتنفيذ:\n\"{goal}\"")
    
    search_data = web_search(goal)
    
    system_instruction = (
        "أنت وكيل أمن سيبراني وبرمجة."
        "قواعد التنسيق:\n"
        "1. يمنع استخدام الجداول نهائياً.\n"
        "2. اكتب تقريراً واضحاً بأسلوب النقاط والقوائم.\n"
        "3. أدرج الكود البرمجي كاملاً فقط داخل ```python ولا تضع أوامر تشغيل سطر الأوامر داخل الكود."
    )
    user_instruction = f"الهدف: {goal}\n\nنتائج البحث:\n{search_data}\n\nاكتب التقرير النهائي والكود البرمجي."
    
    final_output, used_model = call_llm(system_instruction, user_instruction)
    
    if not used_model:
        send_telegram(f"⚠️ {final_output}")
        return

    code_blocks = re.findall(r'```(?:python|bash|json|html|c|cpp|php)?\n(.*?)```', final_output, re.DOTALL)
    
    if code_blocks:
        file_name = "script.py"
        full_code = "\n\n# --- Code Block ---\n\n".join(code_blocks)
        with open(file_name, "w", encoding="utf-8") as f:
            f.write(full_code)
        
        send_telegram_file(file_name, caption=f"📦 ملف الكود البرمجي جاهز.\n🤖 تم التوليد بواسطة: {used_model}")
        if os.path.exists(file_name):
            os.remove(file_name)
            
        clean_report = re.sub(r'```(?:python|bash|json|html|c|cpp|php)?\n.*?```', '📁 (تم إرفاق الملف البرمجي أعلاه)', final_output, flags=re.DOTALL)
    else:
        clean_report = final_output

    send_telegram(f"🤖 تقرير الوكيل الذكي\n⚡ النموذج المستعمل: {used_model}\n📌 الهدف: {goal}\n\n{clean_report}")

def start_bot_listener():
    print("🚀 الوكيل الذكي يعمل ونظام الجلب الأوتوماتيكي مفعّل...")
    send_telegram("✅ تم تفعيل محرك الفحص الذاتي! سيقوم البوت باختيار وتجربة النماذج المجانية أوتوماتيكياً دون تدخل يدوي.")
    
    offset = None
    url = f"{TG_BASE_URL}/getUpdates"
    
    while True:
        try:
            params = {"timeout": 25, "offset": offset}
            res = requests.get(url, params=params, timeout=30).json()
            if "result" in res:
                for update in res["result"]:
                    offset = update["update_id"] + 1
                    message = update.get("message", {})
                    text = message.get("text", "")
                    
                    if text:
                        process_goal(text)
        except Exception as e:
            time.sleep(3)

if __name__ == "__main__":
    start_bot_listener()
