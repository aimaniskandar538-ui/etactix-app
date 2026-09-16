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
