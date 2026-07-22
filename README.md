# Memory

> **Share memories with the people who made them.**  
> Memory is a private short-video platform designed for authentic moments shared exclusively within trusted Circles rather than broadcast to public feeds.

---

## 🌟 Overview

Unlike traditional social media platforms focused on followers, public reach, and viral algorithms, **Memory** asks a fundamental question:
*"Who was actually there?"*

Memory allows users to capture short video moments and share them directly within private **Circles** (e.g., family, close friends, trip companions). It offers a private-by-design experience without public discovery feeds, likes counter pressure, or ad-driven algorithms.

---

## 🏗️ Repository Architecture

This repository is structured as a monorepo containing the full end-to-end ecosystem:

```text
codebase/
├── memory/             # Flutter Mobile Application (Android & iOS)
├── memory-backend/     # NestJS Backend API & Prisma ORM Engine
├── memory-website/     # Next.js 15 Landing Page & Legal Hub
└── .github/workflows/  # CI/CD Pipelines (Build, Test, Analyze, Deploy)
```

---

## 📦 Components Breakdown

### 1. 📱 Mobile App (`/memory`)
- **Framework**: Flutter (Dart) with Riverpod state management.
- **Key Capabilities**:
  - Private short-video camera recording & optimized compression.
  - Circle social graph & contact discovery.
  - Real-time messaging & event bus integration.
  - Push notification system (Firebase Cloud Messaging).
  - Data protection & account management controls.

### 2. ⚡ Backend Service (`/memory-backend`)
- **Framework**: NestJS (TypeScript) & Prisma ORM.
- **Database**: PostgreSQL (Production) / SQLite (Development).
- **Key Capabilities**:
  - JWT Authentication & Session management.
  - Media storage & presigned upload queue pipelines.
  - Circle & member access control permissions (Owner, Admin, Member).
  - FCM push notifications dispatching.
  - Data privacy export & account deletion lifecycle endpoints.

### 3. 🌐 Website (`/memory-website`)
- **Framework**: Next.js 15 (App Router) & React 19.
- **Key Features**:
  - High-performance, fully mobile-responsive landing page introducing the brand.
  - Clean brand identity in Memory Yellow (`#F4C430`), Black, and White.
  - Side-by-side app mockups and interactive FAQ section.
  - Full compliance legal pages (`/privacy` and `/terms`) compliant with the **Kenya Data Protection Act, 2019** and legal frameworks.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>=3.24.0`
- **Node.js**: `>=22.x`
- **npm**: `>=10.x`
- **Docker** (optional, for backend containerization)

---

### Local Development Setup

#### 1. Running the Website (`memory-website`)
```bash
cd memory-website
npm install
npm run dev
# Open http://localhost:3000
```

#### 2. Running the Backend (`memory-backend`)
```bash
cd memory-backend
npm install
npx prisma generate
npx prisma db push
npm run start:dev
# REST API running at http://localhost:3000
```

#### 3. Running the Mobile App (`memory`)
```bash
cd memory
flutter pub get
flutter run
```

---

## 🛠️ CI/CD Pipeline

Continuous Integration & Deployment is automated via **GitHub Actions** (`.github/workflows/ci-cd.yml`):
- **Backend Job**: Installs dependencies, runs linter (`eslint`), generates Prisma client, runs Jest unit tests, and builds the NestJS application.
- **Flutter Job**: Sets up Java 17 & Flutter, runs dependency resolution, verifies code formatting (`dart format`), executes static analysis (`flutter analyze`), runs tests (`flutter test`), and builds a debug APK.
- **Continuous Deployment**: Builds production container images for deployment.

---

## ⚖️ Legal & Privacy Compliance

Memory is committed to strict user privacy standards:
- **Kenya Data Protection Act, 2019**: Full compliance with data minimization, user consent, 30-day data deletion, and data subject rights.
- **Terms of Service**: Governed under the Laws of Kenya.

---

## 👥 Brand & Support

- **Website**: [mymemoriestoday.site](https://mymemoriestoday.site)
- **Instagram**: [@mymemoriestoday](https://www.instagram.com/mymemoriestoday/)
- **TikTok**: [@memoryapp](https://www.tiktok.com/@memoryapp)
- **Powered by**: Evolve
