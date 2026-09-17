import os
import threading
from flask import Flask
from google import genai
import telebot

app = Flask(__name__)


@app.route('/')
def home():
  return 'Bot is alive!'


def run_flask():
  app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))


TELEGRAM_TOKEN = os.environ.get('TELEGRAM_TOKEN')
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')

# استخدام العميل الحديث والمباشر
client = genai.Client(api_key=GEMINI_API_KEY)
bot = telebot.TeleBot(TELEGRAM_TOKEN)


@bot.message_handler(func=lambda message: True)
def handle_message(message):
  try:
    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=(
            'أنت مساعد تسويقي محترف للمتاجر. صغ إعلاناً جذاباً بناءً على الطلب'
            f' التالي: {message.text}'
        ),
    )
    bot.reply_to(message, response.text)
  except Exception as e:
    bot.reply_to(message, f'حدث خطأ: {str(e)[:100]}')


if __name__ == '__main__':
  threading.Thread(target=run_flask).start()
  bot.infinity_polling()
