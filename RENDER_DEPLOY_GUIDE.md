# 🚀 คู่มือการนำ Blox Fruits Tracker ขึ้น Render (onrender.com)
> ใช้งานฟรี 100% ออนไลน์ 24 ชม. ดูผ่านมือถือได้จากทุกที่ทั่วโลก พร้อม HTTPS อัตโนมัติ

---

## 📁 ไฟล์ที่เตรียมไว้ให้พร้อมแล้ว
ในโฟลเดอร์นี้มีไฟล์สำหรับขึ้น Render ครบถ้วนแล้ว:
- `Procfile` : คำสั่งรันผ่าน Gunicorn WSGI Production Server
- `requirements.txt` : รายชื่อไลบรารีที่จำเป็น (Flask, Gunicorn, requests, flask-cors)
- `render.yaml` : ไฟล์ตั้งค่า Blueprint อัตโนมัติ
- `.gitignore` : ป้องกันไฟล์ขยะถูกอัพโหลด

---

## ขั้นตอนที่ 1: นำโค้ดขึ้น GitHub

### วิธีที่ง่ายที่สุด (ผ่านเว็บ GitHub ไม่ต้องใช้คำสั่ง):
1. เข้าเว็บ [github.com](https://github.com) แล้วล็อกอิน
2. กดปุ่ม **New** (สีเขียว) เพื่อสร้าง Repository ใหม่
3. ตั้งชื่อ Repository: `angushubxhunter` แล้วเลือกเป็น **Public** จากนั้นกด **Create repository**
4. ในหน้าถัดไป ให้คลิกที่ลิงก์ **"uploading an existing file"**
5. ลากไฟล์ทั้งหมดในโฟลเดอร์นี้:
   - `app.py`
   - `roblox_script.lua`
   - `requirements.txt`
   - `Procfile`
   - `render.yaml`
   - โฟลเดอร์ `templates/` (มี `dashboard.html`)
   - โฟลเดอร์ `static/` (มีรูปโลโก้ `logo.jpg` และรูปไอคอนทั้งหมด)
6. กดปุ่มสีเขียว **Commit changes**

*(หรือหากถนัด Git CLI: `git init`, `git add .`, `git commit -m "AngusHub v4.2"`, `git push`)*

---

## ขั้นตอนที่ 2: เชื่อมต่อและ Deploy บน Render

1. เข้าเว็บ [dashboard.render.com](https://dashboard.render.com)
2. ล็อกอินด้วยบัญชี **GitHub** ของคุณ
3. ที่หน้า Dashboard กดปุ่ม **New +** มุมขวาบน -> เลือก **Web Service**
4. เลือก Repository `angushubxhunter` ที่คุณเพิ่งอัพโหลด
5. กรอกข้อมูลตั้งค่าดังนี้:
   - **Name**: `angushubxhunter` (Render จะตั้งให้เป็น `https://angushubxhunter.onrender.com`)
   - **Region**: `Singapore` (ใกล้ประเทศไทยที่สุด ปิงน้อยที่สุด)
   - **Branch**: `main`
   - **Runtime**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app --workers 2 --threads 4 --timeout 120`
   - **Instance Type / Plan**: เลือก **Free** ($0/month)
6. เลื่อนลงมากดปุ่ม **Deploy Web Service**
7. รอระบบทำการ Build ประมาณ 1–2 นาที เมื่อเสร็จแล้วสถานะจะขึ้น **Live** พร้อมลิงก์เว็บไซต์:
   `https://angushubxhunter.onrender.com`

---

## ขั้นตอนที่ 3: วิธีใช้งานใน Roblox Executor

เมื่อเว็บของคุณออนไลน์บน Render แล้ว ในเกมให้รันคำสั่ง 1 บรรทัดนี้ได้เลย:

```lua
loadstring(game:HttpGet("https://angushubxhunter.onrender.com/script.lua"))()
```

---

## 📱 การดูข้อมูลผ่านมือถือ
- หยิบมือถือ เปิด Safari หรือ Chrome
- เข้าลิงก์เว็บของคุณ: `https://angushubxhunter.onrender.com`
- ติดตามค่าหัวจริง 7.944M (`≈ 7.94M`), Beli, Fragments และไอเทมแบบเรียลไทม์ 24 ชม. ได้จากทุกที่ทั่วโลก!
