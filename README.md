# TrackMate - Friend-Based Location Tracking App

A Flutter Android application that allows users to track their friends' locations with mutual consent. Built with Firebase backend and Google Maps integration.

## Features

- **User Authentication**: Register and login with username + password
- **Friend System**: Search users, send/accept/reject friend requests
- **Location Tracking**: Request permission to track friends' locations
- **Privacy Controls**: Only track friends who have accepted your request
- **Battery Optimized**: Interval-based location updates (5-60 seconds configurable)
- **Google Maps**: View tracked user's location on an interactive map
- **Real-time Updates**: Location updates stream in real-time via Firestore

## Screenshots

| Login | Home | Friends | Tracking |
|-------|------|---------|----------|
| Login Screen | Dashboard | Friends List | Map View |

## Prerequisites

Before running the app, you need:

1. **Flutter SDK** (3.10.7 or later)
2. **Firebase Project**
3. **Google Maps API Key**

## Setup Guide

### Step 1: Clone and Install Dependencies

```bash
cd trackmate
flutter pub get
```

### Step 2: Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (or use existing)
3. Add an Android app with package name: `com.example.trackmate`
4. Download `google-services.json`
5. Place it in `android/app/google-services.json`

#### Enable Authentication
1. In Firebase Console → Authentication → Sign-in method
2. Enable **Email/Password** provider

#### Setup Firestore
1. In Firebase Console → Firestore Database
2. Create database in **test mode** (for development)
3. The app will auto-create collections: `users`, `friends`, `friend_requests`, `tracking_requests`, `locations`

#### Firestore Security Rules (Production)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Friend requests
    match /friend_requests/{requestId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }
    
    // Friends
    match /friends/{friendId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
    
    // Tracking requests
    match /tracking_requests/{requestId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }
    
    // Locations - only owner can write, authorized users can read
    match /locations/{userId} {
      allow write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null;
    }
  }
}
```

### Step 3: Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable **Maps SDK for Android**
4. Create an API key under Credentials
5. Replace the placeholder in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE"/>
```

### Step 4: Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart      # App-wide constants
│   ├── services/
│   │   ├── firebase_service.dart   # Firebase initialization
│   │   ├── location_service.dart   # Location handling
│   │   └── storage_service.dart    # Local storage
│   ├── theme/
│   │   └── app_theme.dart          # App theming
│   └── utils/
│       └── helpers.dart            # Utility functions
├── features/
│   ├── auth/                       # Authentication feature
│   │   ├── model/
│   │   ├── provider/
│   │   ├── repository/
│   │   └── view/
│   ├── friends/                    # Friends feature
│   │   ├── model/
│   │   ├── provider/
│   │   ├── repository/
│   │   └── view/
│   ├── home/                       # Home dashboard
│   │   └── view/
│   ├── settings/                   # Settings feature
│   │   ├── model/
│   │   ├── provider/
│   │   ├── repository/
│   │   └── view/
│   └── tracking/                   # Location tracking feature
│       ├── model/
│       ├── provider/
│       ├── repository/
│       └── view/
└── main.dart                       # App entry point
```

## Required Permissions

The app requires the following Android permissions:

- `INTERNET` - For Firebase communication
- `ACCESS_FINE_LOCATION` - For precise GPS location
- `ACCESS_COARSE_LOCATION` - For approximate location
- `ACCESS_BACKGROUND_LOCATION` - For location updates when app is minimized

## App Flow

1. **Register/Login** → Create account or login with username
2. **Search Users** → Find friends by username
3. **Send Friend Request** → Request must be accepted
4. **Send Tracking Request** → Friend must accept to enable tracking
5. **View Location** → See friend's real-time location on map
6. **Stop Tracking** → Either party can stop at any time

## Configuration

### Location Update Intervals

Users can choose their preferred location update interval in Settings:
- 5 seconds (more battery usage)
- 10 seconds (default, recommended)
- 15 seconds
- 30 seconds
- 60 seconds (least battery usage)

## Dependencies

- `firebase_core` - Firebase initialization
- `firebase_auth` - User authentication
- `cloud_firestore` - Real-time database
- `google_maps_flutter` - Map display
- `geolocator` - Location services
- `permission_handler` - Runtime permissions
- `provider` - State management
- `url_launcher` - Open external apps
- `shared_preferences` - Local storage
- `intl` - Date formatting

## Troubleshooting

### App crashes on launch
- Ensure `google-services.json` is in `android/app/`
- Check minSdk is 21 or higher

### Google Maps not showing
- Verify API key is correctly placed in AndroidManifest.xml
- Ensure Maps SDK for Android is enabled in Google Cloud Console

### Location not updating
- Grant location permissions when prompted
- Ensure GPS is enabled on device

### Firebase errors
- Check Firebase project configuration
- Verify email/password auth is enabled

## License

MIT License - Feel free to use and modify.
