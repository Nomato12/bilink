# FCM Notification System Setup Instructions

This document explains how to deploy the Firebase Cloud Functions for handling notifications in the BiLink application.

## Overview

Our notification system has three components:

1. **Client-side notification handling** (FCM tokens, receiving notifications)
2. **Firestore for notification storage** (messages, token storage)
3. **Cloud Functions for notification delivery** (sends FCM messages)

## Setup Steps

### 1. Initialize Firebase Functions

```bash
# Install Firebase CLI if you haven't already
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase Functions in the project root
cd d:\bilink
firebase init functions
```

During initialization, select:
- Use an existing project
- JavaScript
- ESLint (optional)
- Install dependencies with npm (Yes)

### 2. Copy Cloud Function Code

Copy the contents of `d:\bilink\functions\index.js` to the newly created `functions/index.js` file.

### 3. Install Dependencies

```bash
cd functions
npm install firebase-admin firebase-functions
```

### 4. Deploy the Functions

```bash
firebase deploy --only functions
```

### 5. Testing Notifications

After deployment, the system works as follows:

1. When a provider accepts a service request, a notification is created in Firestore.
2. The Cloud Function detects the new notification and sends it via FCM to the client.
3. The client receives the notification, displays it locally if the app is open, or shows a system notification if the app is closed.

## Troubleshooting

If notifications are not being received:

1. Check that clients have granted notification permissions
2. Verify FCM tokens are properly saved in Firestore
3. Check Cloud Functions logs for errors
4. Ensure the app has proper notification channels configured

## Security Rules

Make sure your Firestore security rules allow the Cloud Function to read and write to the `fcm_messages` collection.

Example security rules:

```
match /fcm_messages/{messageId} {
  allow read, write: if request.auth != null;
}
```
