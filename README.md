# 5S Digital Assessment

Flutter mobile app for **5S assessments**, **Gemba observations**, and **Skill Matrix** (demo), with a NestJS API in `backend-nest/`.

**Repository:** [https://github.com/Packages-Limited/5s-assessment](https://github.com/Packages-Limited/5s-assessment)

## Apps

- **5S Assessment** — digital 5S audits and follow-up
- **Gemba** — shop-floor observations and reports
- **Skill Matrix** — worker self-assessment and line-manager review (demo data)

## Getting started

### Flutter

```bash
flutter pub get
flutter run
```

API base URL is configured in `lib/src/config/api_config.dart` (debug defaults to local NestJS).

### Backend (NestJS)

See [backend-nest/README.md](backend-nest/README.md). Copy `backend-nest/.env.example` to `backend-nest/.env` and set database and mail settings.

```bash
cd backend-nest
npm install
npm run start:dev
```

## Documentation

- [Flutter docs](https://docs.flutter.dev/)
