<p align="center">
  <img src="https://raw.githubusercontent.com/luqelha/musicalice/main/images/musicalice.png" 
       alt="My Photo" 
       width="150" 
       style="border-radius:50%;"/>
       &nbsp;
  <img src="https://raw.githubusercontent.com/luqelha/musicalice/main/images/searchpage.png" 
       alt="My Photo" 
       width="150" 
       style="border-radius:50%;"/>
       &nbsp;
  <img src="https://raw.githubusercontent.com/luqelha/musicalice/main/images/librarypage.png" 
       alt="My Photo" 
       width="150" 
       style="border-radius:50%;"/>
       &nbsp;
  <img src="https://raw.githubusercontent.com/luqelha/musicalice/main/images/settingspage.png" 
       alt="My Photo" 
       width="150" 
       style="border-radius:50%;"/>
</p>

<p align="center">
  <a href="https://www.spotify.com/" style="text-decoration:none;"><img src="https://img.shields.io/badge/Spotify-1ED760?style=for-the-badge&logo=spotify&logoColor=white"/></a>
  &nbsp;
  <a href="https://flutter.dev/" style="text-decoration:none;"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white"/></a>
  &nbsp;
  <a href="https://dart.dev/" style="text-decoration:none;"><img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white"/></a>
</p>

## 🎧 Musicalice

> [!IMPORTANT]
> Musicalice requires users to authenticate with a valid Spotify Premium subscription.

## ✨ Features

- **🏠 Personalized Home Feed:** Discover curated playlists and personalized song recommendations powered by the Spotify API. See your recently played tracks at a glance.
- **🔍 Powerful Search:** Instantly search Spotify's vast music catalog for tracks and artists.
- **📚 Your Music Library:** Access all your Spotify playlists and liked songs in one place. Sort and filter your library with ease.
- **🎶 Full-Screen Player:** Immerse yourself with a beautiful full-screen player displaying album art, track details, and playback controls (Play/Pause, Next, Previous, Shuffle, Repeat).
- **▶️ Mini Player:** Keep the music playing while you browse. The persistent mini player provides quick access to playback controls from anywhere in the app.
- **⚙️ Settings & Profile:** View your Spotify profile information and manage your login status.
- **🔒 Secure Spotify Login:** Authenticates securely with your Spotify account using OAuth 2.0 and PKCE.
- **📱 Built with Flutter:** Cross-platform compatibility for a consistent experience.

## 🚀 Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

**Prerequisites:**

- Flutter SDK installed (check `flutter doctor`)
- An IDE like VS Code or Android Studio
- A Spotify Developer Account and API Keys (Client ID)

**Installation:**

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/your-username/musicalice.git](https://github.com/your-username/musicalice.git)
    cd musicalice
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Set up Spotify Developer Account:**
    Set up your [Spotify Developer Account](https://developer.spotify.com/dashboard) and create a new app to obtain your **Client ID** and **Redirect URI**.  
    Add these to a `.env` file in the root directory of your project:

    ```env
    SPOTIFY_CLIENT_ID=YOUR_SPOTIFY_CLIENT_ID
    SPOTIFY_REDIRECT_URI=musicalice://callback
    ```

4.  **Run the app:**
    ```bash
    flutter run
    ```
