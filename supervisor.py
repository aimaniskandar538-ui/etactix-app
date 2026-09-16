import os
import sys
import subprocess
import base64

encoded_key = "QVEuQWI4Uk42SWxkMF8zTlRKd3BPNnhRTW82TVYyQU5CRzMtU3ZfekNCSXk0Smx1Wm5LOWc="
os.environ["GEMINI_API_KEY"] = base64.b64decode(encoded_key).decode('utf-8')

print("--- Starting Telegram Bot Application ---")

if os.path.exists("app.py"):
    subprocess.run([sys.executable, "app.py"])
else:
    print("Error: app.py not found!")
