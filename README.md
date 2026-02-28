# Brookie – Cross-Platform Mobile Application (Android & iOS)

## 📌 Overview
**Brookie** is a cross-platform mobile application (Android & iOS) for personal finance management, with a focus on **gamification** and **AI-driven insights**.

This project was developed for the **Human–Computer Interaction (HCI)** class at **NTUA ECE** and was **one of only three projects that year** to receive a **5.0/5.0** grade.

The app promotes healthy financial habits through:
- **Leaderboards** and **badges**
- **User comparison** (peer comparison)
- An **AI assistant** that provides personalized guidance

Brookie is implemented with a **single cross-platform codebase** and connects to a **remote cloud backend**.

---

## a) Installation & usage instructions (for non-technical users)

### 🔹 App installation (Android)
1. Download the app **APK** to your Android phone.
2. Open `brookie.apk`.
3. If a security prompt appears:
  - Select “**Install from this source**”.
4. Complete the installation.

### 🔹 App installation (iOS)
The app is cross-platform and also works on iOS (iPhone) via the same implementation.  
For evaluation convenience, an **Android APK** is provided so installation is immediate without additional steps.

### 🔹 Sign in
For easier evaluation, a ready-to-use account with preloaded data is provided:

```txt
Username: grader
Password: Test12345!
```

---

## 🔹 Core features

### 🏦 Bank account management (Mock)
Users can add a bank account.

Accounts are **mock (simulated)**:
- No integration with real bank APIs (to avoid complexity and security concerns).
- Mock accounts:
  - generate realistic expenses
  - simulate real transaction activity

### 🤖 AI-powered automatic expense categorization
Expenses from bank accounts are:
- analyzed by the AI assistant
- categorized automatically
- added to the user’s spending data

### 📊 Budgets & spending tracking
Users can:
- set budgets per category
- track spending progress in real time

Visualizations include:
- a **Budget Wheel**
- detailed category **insights**

### 🏆 Gamification
- User comparison **leaderboard**
- **Badges** & achievements

Motivation to:
- reduce expenses
- reach goals
- maintain consistent financial behavior

### 🤖 Smart AI Assistant & insights
The AI assistant:
- analyzes the user’s budgets and spending
- compares the user with other app users
- provides:
  - personalized financial advice
  - money-saving suggestions
  - peer comparisons (vs. averages)
  - suggestions for cheaper stores/options

AI insights are based on:
- the user’s behavior
- aggregated data from other users

### 🧾 Receipt analysis
- Capture a receipt photo
- Automatic recognition of:
  - amount
  - category
  - date
- Automatic addition to the user’s spending

---

## 🔹 Backend & service availability
The backend runs remotely on **Render (cloud)**.

The app:
- does not require a local database
- does not require any user configuration

All services (API, database, AI services) will be available until:
- 📅 **7/2/2025** (end of the winter exam period)

---

## b) SDK / Platforms / Links

### 🔧 Platforms
- **Android:** Android 14.0+ (API 34)
- **iOS:** iOS 13+
- **Cross-platform app** (single codebase)

### 🔗 Links
- **Backend API (Remote):**
  - https://brookie-qmcm.onrender.com
- **Repository:** https://github.com/Zajason/Brookie/tree/serverside

