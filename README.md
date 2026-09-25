# Prime Care Medical Office Assistant (Hackers-Healers-1)

A professional, full-stack web application designed for primary care clinics. This application features AI-powered tools to reduce administrative burden, including an Ambient Voice Scribe, OCR Form Filler, and Secure Inbox Triage.

## How to Run the App

The application consists of a **FastAPI backend** (which also serves the frontend UI) and a **React/Vite frontend**. 

### Step 1: Start the Backend Server
Open your terminal (Command Prompt or PowerShell) and run the following commands:
```bash
cd path\to\Hackers-Healers-1\backend
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*Note: Using `--host 0.0.0.0` allows access from other devices (like your smartphone) on your local Wi-Fi.*

### Step 2: Access the App
* **On your PC**: Open your web browser and go to: **http://localhost:8000**
* **On your Smartphone / Mobile Device**: 
  1. Make sure your phone is on the **same Wi-Fi network** as your PC.
  2. Open Safari or Chrome on your phone and go to: **http://192.168.2.29:8000** (or your PC's current Wi-Fi IP from `ipconfig`).
  3. *(Optional)* Tap **Share > Add to Home Screen** on iPhone or **Install App / Add to Home screen** on Android to use it like a native mobile app!

---

## (Optional) Development Mode & Making Changes
If you want to edit the User Interface and see changes happen live without rebuilding, you can use the Vite Development Server.

1. Open a **second** terminal window.
2. Navigate to the frontend directory and start the dev server:
```bash
cd path\to\Hackers-Healers-1\frontend
npm run dev
```
3. Open your browser to **http://localhost:5173** to view the live-reloading version.

*Note: Whenever you are finished making UI changes, you must run `npm run build` in the `frontend` folder so the main backend (port 8000) gets the updated files!*

## Local AI Integration (Ollama)
For the Ambient Scribe to process real voice dictations privately on your machine, make sure you have **Ollama** running in the background with the `gemma2:2b` model installed. (If Ollama is not running, the app gracefully falls back to a realistic mock-data generator).
