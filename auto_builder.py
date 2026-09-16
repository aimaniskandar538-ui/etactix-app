import subprocess

app_update_code = '''
# --- إضافة شريط التواصل والتفعيل الآلي ---
import streamlit as st

st.sidebar.title("🔑 التفعيل والدعم الفني")
st.sidebar.info("لتفعيل النسخة الكاملة أو طلب الدعم المباشر:")
st.sidebar.markdown("[💬 تواصل مباشر عبر تلغرام](https://t.me/YourTelegramUsername)")
st.sidebar.code("FREIGHT-2026-PRO", language="text")
'''

print("[+] جاري تعديل كود التطبيق تلقائياً...")
with open("app.py", "a", encoding="utf-8") as f:
    f.write(app_update_code)

print("[+] جاري رفع التحديثات إلى Streamlit Cloud...")
commands = [
    "git config user.name 'TermuxAuto'",
    "git config user.email 'auto@freightdoc.ai'",
    "git add app.py",
    "git commit -m 'Auto update sidebar contact and trial keys'",
    "git push origin main"
]

for cmd in commands:
    subprocess.run(cmd, shell=True)

print("[✓] تم تحديث التطبيق أوتوماتيكياً على الإنترنت!")
