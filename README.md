LINK GITHUB : (https://github.com/ieeeessthssb-design/RentGo-Tunisia)

**A smart mobile platform for electric bike and scooter rental in Tunisia.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter\&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart\&logoColor=white)](https://dart.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?logo=node.js\&logoColor=white)](https://nodejs.org/)
[![Express.js](https://img.shields.io/badge/Express.js-REST%20API-000000?logo=express\&logoColor=white)](https://expressjs.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-4169E1?logo=postgresql\&logoColor=white)](https://www.postgresql.org/)
[![Google Maps](https://img.shields.io/badge/Google%20Maps-API-4285F4?logo=googlemaps\&logoColor=white)](https://developers.google.com/maps)


## About the Project

**RentGo Tunisia** is a mobile application designed to provide a convenient and accessible solution for renting electric bikes and scooters.

Developed as an **end-of-year academic group project by a four-member team**, the project demonstrates the design and implementation of a full-stack mobile solution combining:

* A cross-platform mobile application built with **Flutter/Dart**
* A **Node.js/Express REST API**
* A relational **PostgreSQL database**
* **Google Maps** integration for location-based vehicle discovery
* Authentication and role-based access
* Reservation and ride management
* An in-app wallet for ride payments

The project was developed following the **Scrum Agile methodology** and documented through an academic report following an **Esprit-style structure**.

> **Implementation note:** This repository documents the features that were actually implemented and tested. Features that exist only at the UI level or remain planned are explicitly identified rather than presented as completed functionality.

---

## Table of Contents

* [About the Project](#about-the-project)
* [Key Features](#key-features)
* [Technology Stack](#technology-stack)
* [System Architecture](#system-architecture)
* [Application Roles](#application-roles)
* [Project Structure](#project-structure)
* [Getting Started](#getting-started)

  * [Prerequisites](#prerequisites)
  * [Backend Setup](#backend-setup)
  * [Database Setup](#database-setup)
  * [Frontend Setup](#frontend-setup)
  * [Environment Variables](#environment-variables)
* [API Overview](#api-overview)
* [Implementation Status](#implementation-status)
* [Known Limitations](#known-limitations)
* [Future Evolutions](#future-evolutions)
* [Team](#team)
* [Academic Documentation](#academic-documentation)
* [License](#license)

---

# Key Features

## Rider Features

### Vehicle Discovery

* Browse available electric bikes and scooters.
* View vehicles through a map-based interface.
* Display vehicle locations using Google Maps integration.

### Authentication

* User registration and login.
* Authentication through the backend API.
* Role-based application screens.

### Reservation & Ride Management

* Reserve an available vehicle.
* Follow the rider journey from reservation to ride completion.
* Start and end a ride through the application.

### Vehicle Unlocking

* Unlock vehicles using a **manual unlock code**.
* The current implementation does **not** use camera-based QR scanning.

### In-App Wallet

* View wallet balance.
* Add funds to the application wallet.
* Deduct ride costs from the wallet.

> **Payment scope:** RentGo Tunisia currently uses an internal wallet system. No external banking or online payment gateway is integrated.

---

# Application Roles

The application currently defines the following main roles:

| Role                 | Responsibilities                                                                                                  |
| -------------------- | ----------------------------------------------------------------------------------------------------------------- |
| **Rider**            | Discover vehicles, make reservations, start/end rides, unlock vehicles, and manage wallet payments                |
| **Operator / Admin** | Fleet-management interface exists at the UI level; backend administration endpoints are not currently implemented |

The distinction between implemented functionality and UI-only functionality is intentionally maintained for technical and academic accuracy.

---

# Technology Stack

| Layer                       | Technology                           |
| --------------------------- | ------------------------------------ |
| **Mobile Application**      | Flutter / Dart                       |
| **Backend**                 | Node.js / Express.js                 |
| **API Architecture**        | REST                                 |
| **Database**                | PostgreSQL                           |
| **Database Management**     | SQL schema + runtime migrations      |
| **Maps & Geolocation**      | Google Maps API                      |
| **Authentication**          | Token-based authentication           |
| **Development Methodology** | Scrum / Agile                        |
| **Documentation**           | LaTeX / Esprit-style academic report |

---

# System Architecture

RentGo Tunisia follows a **three-tier architecture** separating the presentation, application, and data layers.

```text
┌─────────────────────────────┐
│       Flutter Mobile App    │
│                             │
│  Dart • UI • Services       │
│  Authentication • Maps      │
└──────────────┬──────────────┘
               │
               │ HTTP / REST
               ▼
┌─────────────────────────────┐
│      Node.js / Express      │
│                             │
│  REST API                   │
│  Business Logic             │
│  Authentication             │
│  Reservations & Rides       │
│  Wallet Management          │
└──────────────┬──────────────┘
               │
               │ SQL
               ▼
┌─────────────────────────────┐
│         PostgreSQL          │
│                             │
│  Users • Vehicles           │
│  Reservations • Rides       │
│  Wallet & Application Data  │
└─────────────────────────────┘

               ▲
               │
               │ Google Maps API
               │
        ┌──────┴──────┐
        │ Google Maps │
        │ Location &  │
        │ Map Display │
        └─────────────┘
```

### Architecture Responsibilities

**Flutter Mobile Application**

Responsible for the user interface, navigation, rider workflows, map visualization, and communication with the backend API.

**Node.js / Express Backend**

Provides the REST API and handles authentication, application logic, reservations, ride operations, and wallet-related transactions.

**PostgreSQL Database**

Stores the application's persistent relational data.

**Google Maps API**

Provides map and location functionality used for vehicle discovery and location visualization.

---

# Project Structure

```text
RentGo-Tunisia/
│
├── backend/
│   ├── routes/
│   │   └── ...                 # REST API route handlers
│   │
│   ├── config/
│   │   └── db.js               # Database connection & migrations
│   │
│   ├── schema.sql               # PostgreSQL database schema
│   └── server.js                # Backend entry point
│
├── lib/
│   ├── screens/                 # Application screens
│   ├── widgets/                 # Reusable Flutter widgets
│   └── services/                # API and application services
│
├── docs/
│   └── RENTGO_TUNISIA_FULL_TECHNICAL_REPORT.txt
│
├── README.md
└── ...
```

> **Note:** The structure above represents the organization documented for the project. Additional Flutter-generated and platform-specific directories may exist in the repository.

---

# Getting Started

## Prerequisites

Before running the project, make sure the following tools are installed:

* **Flutter SDK 3.x or later**
* **Dart 3.x**
* **Node.js 18 or later**
* **npm**
* **PostgreSQL 14 or later**
* **Android Studio** for Android development
* **Xcode** for iOS development (macOS only)
* A configured **Google Maps API key**

Verify your installations:

```bash
flutter --version
dart --version
node --version
npm --version
psql --version
```

---

# Backend Setup

Navigate to the backend directory:

```bash
cd backend
```

Install dependencies:

```bash
npm install
```

Create the environment configuration file:

```bash
cp .env.example .env
```

If `.env.example` is not present, create `.env` manually using the variables described in the [Environment Variables](#environment-variables) section.

Start the backend:

```bash
npm start
```

The API will be available at:

```text
http://localhost:<PORT>
```

The default development port is typically:

```text
http://localhost:3000
```

> The exact port is determined by the backend configuration.

---

# Database Setup

Create the PostgreSQL database:

```bash
createdb rentgo_tunisia
```

Alternatively, using PostgreSQL's interactive terminal:

```bash
psql
```

Then:

```sql
CREATE DATABASE rentgo_tunisia;
```

The backend uses the project's PostgreSQL schema and applies the required database setup through the backend database configuration.

The base schema is defined in:

```text
backend/schema.sql
```

Database connectivity is configured through:

```text
backend/config/db.js
```

---

# Frontend Setup

Install Flutter dependencies from the **Flutter project root**:

```bash
flutter pub get
```

Connect an Android/iOS device or start an emulator, then run:

```bash
flutter run
```

### Google Maps Configuration

Copy `lib/src/maps_config.example.dart` to `lib/src/maps_config.dart` and
replace the placeholder with a restricted Google Maps API key. The local
`maps_config.dart` file is intentionally ignored by Git.

Configure your Google Maps API key according to the target platform.

**Android**

```text
android/app/src/main/AndroidManifest.xml
```

**iOS**

```text
ios/Runner/AppDelegate.swift
```

Make sure the required Google Maps APIs are enabled in your Google Cloud project.

---

# Environment Variables

Create a `.env` file inside the backend directory.

Example:

```env
PORT=3000

DATABASE_URL=postgresql://user:password@localhost:5432/rentgo_tunisia

GOOGLE_MAPS_API_KEY=your_google_maps_api_key

JWT_SECRET=your_secure_jwt_secret
```

### Important

Do **not** commit secrets, passwords, API keys, or production credentials to GitHub.

Add sensitive environment files to `.gitignore`:

```gitignore
.env
.env.*
!.env.example
```

If the actual backend configuration uses different variable names, use the names defined in the project's source code rather than copying the example blindly.

---

# API Overview

The Flutter application communicates with the backend through a REST API.

The main API domains include:

| Category           | Purpose                                                   |
| ------------------ | --------------------------------------------------------- |
| **Authentication** | Registration, login, and token/session management         |
| **Vehicles**       | Retrieve available bikes/scooters and vehicle information |
| **Reservations**   | Create and manage vehicle reservations                    |
| **Rides**          | Start/end rides and process vehicle unlocking             |
| **Wallet**         | Retrieve balance, add funds, and process ride deductions  |

### Administrative API

The current backend does **not** provide dedicated administrative endpoints.

The administrative dashboard is present in the mobile application's interface, but it is not currently connected to a corresponding backend administration API.

For the complete verified endpoint list, refer to **Chapter III of the academic technical report**.

---

# Implementation Status

The following table distinguishes implemented functionality from interface-only and future functionality.

| Functionality                      |      Status     |
| ---------------------------------- | :-------------: |
| User registration & authentication |   Implemented   |
| Vehicle browsing                   |   Implemented   |
| Map-based vehicle discovery        |   Implemented   |
| Vehicle location display           |   Implemented   |
| Reservations                       |   Implemented   |
| Ride workflow                      |   Implemented   |
| Manual vehicle unlocking           |   Implemented   |
| In-app wallet                      |   Implemented   |
| Wallet-based ride payment          |   Implemented   |
| Rider mobile screens               |   Implemented   |
| Admin dashboard UI                 |     UI only     |
| Admin backend endpoints            | Not implemented |
| Issue reporting UI                 |     UI only     |
| Issue reporting backend            | Not implemented |
| Camera-based QR scanning           | Not implemented |
| External payment gateway           | Not implemented |

This status table is intentionally conservative and reflects the documented implementation rather than planned functionality.

---

# Known Limitations

The current version of RentGo Tunisia has several technical limitations:

### 1. Wallet-Based Payments

Payments are handled exclusively through the application's internal wallet.

No external payment provider or banking gateway is currently integrated.

### 2. Manual Vehicle Unlocking

Vehicle unlocking is performed through manual code entry.

A camera-based QR-code scanning workflow is not currently implemented.

### 3. Administrative Backend

The administrative dashboard exists at the interface level, but the backend does not currently expose dedicated administrative endpoints.

### 4. Issue Reporting

An issue-reporting screen is available in the application interface, but there is currently no corresponding backend endpoint for submitting or processing reports.

---

# Future Evolutions

The following improvements have been identified as potential future developments:

* Full administrative REST API
* Fleet management and vehicle status administration
* Camera-based QR-code scanning
* Backend-powered issue reporting
* External payment gateway integration
* More advanced real-time vehicle tracking
* Enhanced ride monitoring and analytics
* Expanded operator management capabilities

These items are presented as **future evolutions**, not as currently implemented features.



# Academic Documentation

The project is accompanied by a comprehensive technical report documenting the system's analysis, design, implementation, testing, and technical decisions.

**Technical Report:**

```text
docs/RENTGO_TUNISIA_FULL_TECHNICAL_REPORT.txt
```

The report follows an **Esprit-style academic structure** and provides additional technical details, including the verified API documentation and implementation analysis.

---

# Project Repository

**GitHub Repository**

https://github.com/ieeeessthssb-design/RentGo-Tunisia

---

# License

This project was developed for **academic and educational purposes**.

If a specific open-source license is intended for the repository, add the corresponding `LICENSE` file and update this section accordingly.

---

## Project Status

**Academic Project — Developed and documented as part of an end-of-year group project.**

RentGo Tunisia demonstrates the implementation of a full-stack mobile rental platform while explicitly distinguishing between completed functionality, UI-level prototypes, and proposed future developments.
