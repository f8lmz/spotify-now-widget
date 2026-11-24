# Spotify Now

Spotify Now is a macOS menu bar app and a desktop widget for the Spotify desktop app. It shows album art, title, artist, album, and play/pause state, with a progress bar and previous, play/pause, and next.

It reads the Spotify app on this Mac with AppleScript. There is no Spotify account login.

## Screenshots

Screenshots are not checked in yet. Add them under `docs/` and drop the paths in here:

- Menu bar player: `docs/menu-bar.png`
- Medium widget: `docs/widget-medium.png`
- Large widget: `docs/widget-large.png`

## Requirements

- macOS 14 or later
- Xcode 16 or later
- The Spotify desktop app (not the website)

A free Apple ID is enough. You do not need a paid Apple Developer Program membership.

## Build and install

1. Open `SpotifyNow.xcodeproj` in Xcode.
2. If Xcode offers to upgrade the project, click **Perform Changes**. Wait until package resolution finishes. The package is already in this repository.
3. Select the **Spotify Now** scheme and **My Mac**.
4. In the project editor, select the **Spotify Now** target, open **Signing & Capabilities**, turn on **Automatically manage signing**, and choose your Personal Team. Do the same for the **SpotifyNowWidget** target. Both targets must use the same team.
5. If Xcode says the bundle identifier is unavailable, change `com.example.spotifynow` and `com.example.spotifynow.widget` to ids you own, such as `com.yourname.spotifynow` and `com.yourname.spotifynow.widget`. Leave the App Group as `$(TeamIdentifierPrefix)app.spotifynow`.
6. Choose **Product → Archive**.
7. In the Organizer, select the archive, click **Distribute App**, choose **Custom**, then **Copy App**.
8. Move `Spotify Now.app` from the exported folder into **Applications**.
9. Open Spotify Now from Applications. It has no Dock icon. A music note appears in the menu bar.
10. When macOS asks to control Spotify, click **OK**. If you miss the prompt, open **System Settings → Privacy & Security → Automation** and allow Spotify Now to control Spotify.
11. Right-click the desktop, choose **Edit Widgets**, and add **Spotify Now**. It can also be added from Notification Center.

Leave the menu bar app running. The widget reads the song from that app.

## Troubleshooting

**The widget is empty.** Confirm Spotify Now is allowed to control Spotify under **System Settings → Privacy & Security → Automation**. Then remove the widget and add it again.

## Add to Playlist

Adding a song to a playlist uses the Spotify Web API. You create the Spotify app yourself. Spotify Now never ships a client secret.

1. Open [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) and log in with the Spotify account that owns the playlists.
2. Create an app. The name can be anything, such as Spotify Now.
3. In the app settings, add this redirect URI exactly: `spotifynow://callback`
4. Copy the Client ID.
5. Open Spotify Now, click **Spotify Account…**, paste the Client ID, click **Save**, then **Sign In**.
6. Approve the request in the browser. macOS returns to Spotify Now.

In the menu bar panel, open **Add to Playlist**. The list is every playlist you own, plus collaborative playlists you can edit. Click one to add the song that is playing in the Spotify desktop app.

The medium and large widgets have one **Add to Playlist** button beside the playback controls. It opens the same list. Widgets cannot show a dropdown, so the picker is a small window.

Spotify development mode only lets the app owner and the users added on that app’s settings page sign in. The limit is shown in the Spotify dashboard. Playlists you only follow, and do not own or collaborate on, are not listed. Local files, ads, and podcast episodes cannot be added. If the song is already in the playlist, Spotify Now leaves it there and says so.

**The widget says Spotify Now isn’t running.** Open the app from Applications. The music note has to stay in the menu bar.

**Signing failed.** Set the same Personal Team on both targets. Do not choose Sign to Run Locally.

## How it works

The menu bar app listens for Spotify’s playback notification and also checks Spotify with AppleScript. It writes the current song and artwork into an App Group container named with your team id (`$(TeamIdentifierPrefix)app.spotifynow`). The widget reads that folder. Widget buttons write a command file, and the menu bar app sends play, pause, and skip to Spotify.

Tests for the playback parsing live in `Packages/SpotifyNowShared`:

```
cd Packages/SpotifyNowShared
swift test
```

## Disclaimer

Spotify Now is not affiliated with or endorsed by Spotify. Spotify is a trademark of Spotify AB.
