# Lumina

Lumina is a free Android app in development that helps students find scholarships, understand eligibility requirements, and keep track of deadlines.

## What we're building

- Browse scholarships and filter by eligibility, field of study, and deadline.
- Check scholarship details against official sources.
- Save opportunities and track application progress.
- Ask an AI assistant to explain requirements or make a preparation checklist.

## How the AI works

The assistant is designed to use Gemini Nano on supported Android devices. When Nano is unavailable, it can use cloud Gemini through Firebase AI Logic if the user allows cloud processing and has an internet connection.

## Tech stack

Flutter and Dart for the app, Kotlin for the Android AI integration, and Firebase for authentication, scholarship data, and hybrid AI.

Android package name: `com.lumina.app`.
