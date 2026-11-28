# Installing the Lumina APK

How to install and try the Lumina Android app from an APK file.

## Requirements

- An Android 8.0 or newer phone with an internet connection.
- For on-device AI: a phone that supports Gemini Nano. Other phones can use cloud AI.

## Install

1. Copy `app-release.apk` to the phone, or open the download link on the phone.
2. Open the file. If Android asks, allow installing apps from this source.
3. Tap **Install**, then **Open**.

If Android says the app conflicts with an existing package, uninstall any earlier Lumina build
and install again.

## Sign in

Use the test account shared with the submission, or sign in with Google or a new email account.

## Try it

1. **Browse:** filter scholarships by education level, funding type, host country and field of
   study, and open one to see its requirements and deadline.
2. **Save:** save a scholarship, then move it from Saved to Preparing and Applied on the Saved tab.
3. **Ask AI:** ask about a scholarship's requirements, or make a preparation checklist.
4. **Profile:** change the look under Customize look, or turn on dark mode.

## How Ask AI answers

Lumina uses Firebase AI Logic in hybrid mode: Gemini Nano on the phone first, cloud Gemini only
when you allow it. Each answer says where it was made: **Answered on this phone** or **Answered
with cloud AI**.

- On phones with Gemini Nano, answers are made on the phone.
- When Nano is unavailable and cloud AI is on (Profile > Privacy & AI), answers come from cloud
  Gemini. Cloud AI is used only while it is turned on.
- With cloud AI off and no Nano, Ask AI explains that on-device AI is unavailable and offers to
  turn cloud AI on.

Profile > Privacy & AI shows whether on-device AI is ready and which model the phone uses.

## Using Gemini Nano 4 (optional)

Lumina asks for **Gemini Nano 4** first. Gemini Nano 4 is still a preview model, so a phone has it
only after the steps below, and only if AICore offers it for that phone. Without them, Lumina uses
the phone's regular Gemini Nano.

1. In the Play Store, update **AICore** and **Private Compute Services**.
2. Turn on Developer options (Settings > About phone, tap the build or OS version number seven
   times).
3. Search Settings for `AICore` and turn on **Enable AICore Developer Preview**.
4. Keep the phone on Wi-Fi and charging until Gemini Nano 4 has downloaded (several GB).
5. Close Lumina from Recent apps and open it again. Profile > Privacy & AI shows the model name.
