# 5S Backend (NestJS + MySQL + JWT)

This backend replaces Firebase backend services with NestJS + MySQL while preserving your current app flow.

## What is implemented

- JWT auth (`/auth/register`, `/auth/login`)
- Users API (`/users`, `/users/employee/:employeeId`)
- Questions CRUD (`/questions`)
- Assessment submit/list/detail (`/assessments/submit`, `/assessments`, `/assessments/:id`)
- Upload images (`/uploads/images`)
- SMTP email sending when assessment is submitted
- Firebase -> MySQL migration script with default imported password `12345678`

## 1) Configure environment

Copy `.env.example` to `.env` and set values:

- `DATABASE_URL` (MySQL)
- `JWT_SECRET`
- SMTP values
- `FIREBASE_SERVICE_ACCOUNT_PATH` (for migration script)

## 2) Prepare DB schema

```bash
npx prisma generate
npx prisma migrate dev --name init
```

After this, all tables are available in MySQL and visible in phpMyAdmin.

## 3) Run backend

```bash
npm run start:dev
```

Default port: `3000`.

## 4) Migrate Firebase data to MySQL

```bash
npm run seed:firebase
```

This script migrates:

- `company/main/users` -> `User`
- `questions` -> `Question`
- user embedded `assessments[]` -> `Assessment`, `AssessmentItem`, `Attachment`

Imported users are assigned password: `12345678` (hashed in DB).

## 5) Basic API tests

```bash
# Register
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"12345678","name":"Admin","role":"admin"}'

# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"12345678"}'
```

Use returned token as:

`Authorization: Bearer <accessToken>`

## Notes

- This backend keeps the same major domain entities as Firebase to minimize Flutter-side errors.
- For production, change imported default passwords and enforce resets.
