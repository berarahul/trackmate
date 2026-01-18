# Firebase Configuration Fix

I have identified the issues causing `PERMISSION_DENIED`, `SecurityException`, and missing data in lists.

## 1. Missing SHA-1 Fingerprint (Fixes `SecurityException`)

The error `Unknown calling package name` indicates your local development environment's digital signature is not recognized by Firebase.

**Action:** Add your Debug SHA-1 to the Firebase Console.

1.  Go to [Firebase Console](https://console.firebase.google.com/) > **Project Settings** (gear icon).
2.  Scroll down to **Your apps** and select the Android app (`com.example.trackmate`).
3.  Click **Add fingerprint**.
4.  Paste this SHA-1:
    ```
    AC:50:0B:15:E0:05:03:C9:3A:4B:E8:89:7D:E2:B7:22:E6:B9:A3:82
    ```
5.  Click **Save**.
6.  **Download `google-services.json`** again and replace the one in `android/app/google-services.json`.

## 2. Firestore Security Rules (Fixes `PERMISSION_DENIED`)

**Action:** Go to **Firestore Database** > **Rules** and replace EVERYTHING with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users: Allow public read for username check
    match /users/{userId} {
      allow read: if true;
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
    
    // Locations
    match /locations/{userId} {
      allow write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null;
    }
  }
}
```

## 3. Missing Indexes (Fixes requests not showing up)

Firestore requires composite indexes for complex queries.

**Index 1: Friend Requests**
[Create Friend Requests Index Link](https://console.firebase.google.com/v1/r/project/trackmate-726cc/firestore/indexes?create_composite=Cldwcm9qZWN0cy90cmFja21hdGUtNzI2Y2MvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2ZyaWVuZF9yZXF1ZXN0cy9pbmRleGVzL18QARoKCgZzdGF0dXMQARoMCgh0b1VzZXJJZBABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI)
*   Collection: `friend_requests`
*   Fields: `toUserId` (Asc), `status` (Asc), `createdAt` (Desc)

**Index 2: Tracking Requests**
[Create Tracking Requests Index Link](https://console.firebase.google.com/v1/r/project/trackmate-726cc/firestore/indexes?create_composite=Cllwcm9qZWN0cy90cmFja21hdGUtNzI2Y2MvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3RyYWNraW5nX3JlcXVlc3RzL2luZGV4ZXMvXxABGgoKBnN0YXR1cxABGg0KCXRyYWNrZWRJZBABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI)
*   Collection: `tracking_requests`
*   Fields: `trackedId` (Asc), `status` (Asc), `createdAt` (Desc)

## 4. Rebuild

After making these changes:
1.  Stop the app completely.
2.  Run `flutter clean`.
3.  Run `flutter run`.
