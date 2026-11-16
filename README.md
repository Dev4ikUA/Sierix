# Sierix

**A native Gemini AI client for macOS.**

Sierix is a lightweight macOS application built with Swift, designed to bring Google's Gemini AI to the desktop through a clean, native-looking interface.

Currently available as a **Sigma (rolling) release**.

## Features

- **Google Gemini API** — communicate with Gemini models through Google's API.
- **Native macOS UI** — a clean and visually appealing interface.
- **Swift-powered** — written in Swift 4.2.
- **Lightweight** — designed with older macOS versions in mind.

## Tech Stack

| Component | Version |
|---|---|
| Language | Swift 4.2 |
| IDE | Xcode 10.1 |
| API | Google Gemini API |
| Platform | macOS 10.12+ |

## Release Status

**Sigma (rolling)**

Sierix is currently in an early rolling-release stage.

This means:
- Features and UI may change between builds.
- Some functionality may be incomplete.
- Bugs and unexpected behavior are possible.
- Compatibility and stability are still being worked on.

This release is intended for experimentation and feedback rather than production use.

## Configuration

Sierix requires a Google Gemini API key.

Configure your key locally using `Config.plist`.

**Important:** Never commit your API key or your local `Config.plist` to the repository.

## Building

Requirements:

- macOS
- Xcode 10.1
- Swift 4.2

Open the project in Xcode, select the Sierix target, and build the application.

## License

See [LICENSE](LICENSE) for license information.

---

*Made with Swift for macOS.*
