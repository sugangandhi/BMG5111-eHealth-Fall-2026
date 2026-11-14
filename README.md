# eHospital Smart Health (Flutter Mobile & Web + Clinical AI Backend)

A comprehensive, production-grade cross-platform **Flutter** application and **FastAPI** clinical reasoning backend built for modern eHealth systems, wearable telemetry monitoring, and two-way WhatsApp patient-physician care team integration.

---

## 🌟 Architecture Overview

```
Hackers-Healers-1/
├── .github/workflows/android-apk.yml    # CI/CD: Automated versioned Android release APK builder
├── render.yaml                          # Production Render deployment specification
├── README.md                            # Project documentation
├── .gitignore                           # Repository ignore rules
└── flutter_smart_health/                # Complete Flutter & AI Backend project root
    ├── src/
    │   ├── app/                         # Flutter Cross-Platform Client (Android, iOS, Web)
    │   │   ├── lib/                     # Application source code (Bloc architecture)
    │   │   │   ├── core/                # Theme, constants, network clients
    │   │   │   └── features/            # Feature modules:
    │   │   │       ├── auth/            # Patient authentication & session management
    │   │   │       ├── health_assistant/# Conversational AI & WhatsApp Care Team sync
    │   │   │       ├── wearables/       # Apple Watch & Wearable telemetry synchronization
    │   │   │       ├── urgent_care/     # CTAS Triage & emergency queue integration
    │   │   │       ├── nutrition/       # Dietary & meal intake tracking
    │   │   │       ├── stress/          # Stress, recovery & HRV analysis
    │   │   │       └── sleep/           # Circadian cycle & sleep stage analytics
    │   │   ├── pubspec.yaml             # Flutter project manifest & dependencies
    │   │   └── test/                    # Unit & integration test suites
    │   └── backend/                     # Python FastAPI AI & Telemetry Engine
    │       ├── api/                     # REST API routers (WhatsApp, Assistant, Wearables, etc.)
    │       ├── core/                    # App configuration & structured logging
    │       ├── services/                # Clinical reasoning engine (GPT-4o), LangGraph agent
    │       └── main.py                  # Server entrypoint (serves APIs & Flutter Web distribution)
    ├── web_dist/                        # Pre-compiled high-performance Flutter Web bundle
    ├── requirements.txt                 # Backend Python dependencies
    ├── tasks.ps1                        # PowerShell development automation task runner
    └── Makefile                         # Unix / macOS make target runner
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `^3.24.0` (Dart `^3.5.0`)
- **Python**: `3.10+`
- **Git**

---

### 1. Running the Flutter Client

Navigate to the Flutter app directory:
```bash
cd flutter_smart_health/src/app
flutter pub get
```

#### Run on Mobile (Android / iOS):
```bash
flutter run
```

#### Run in Web Browser:
```bash
flutter run -d chrome
```

#### Run Flutter Tests:
```bash
flutter test
```

---

### 2. Running the Clinical Backend Server

The backend powers GPT-4o clinical triage, LangGraph wearable reasoning, and two-way Meta WhatsApp webhook synchronization.

```bash
cd flutter_smart_health
pip install -r requirements.txt
uvicorn src.backend.main:app --host 0.0.0.0 --port 8080 --reload
```

- **Swagger API Docs**: `http://localhost:8080/docs`
- **Web App**: `http://localhost:8080/` (FastAPI automatically serves the built Flutter Web app)

---

## 📱 Features

1. **Two-Way WhatsApp Clinical Care Team**:
   - Meta Cloud API integration.
   - Live synchronization between real patient WhatsApp messages and in-app care team inbox.
   - Clear visual differentiation between **Clinic AI Assistant Bot 🤖** and **Attending Physician 👨‍⚕️**.
   - Automated vital signs extraction (blood pressure, heart rate) parsed directly to clinical charts.

2. **Wearables & Vital Telemetry**:
   - Continuous Apple Watch and Android Health Connect telemetry synchronization.
   - Real-time clinical anomaly detection and threshold alerts.

3. **Clinical Reasoning & Emergency Triage**:
   - Canadian Triage and Acuity Scale (CTAS) AI risk scoring powered by GPT-4o.
   - One-touch consultation booking and urgent care check-ins.

4. **Automated CI/CD**:
   - **Android**: GitHub Actions workflow automatically builds, signs, and publishes versioned release APKs.
   - **Cloud**: Render deploys backend and web client automatically on git push.
