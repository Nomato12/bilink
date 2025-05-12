/**
 * Firebase Cloud Functions to handle sending FCM notifications
 * 
 * This code should be deployed to Firebase Cloud Functions to process
 * notifications stored in the `fcm_messages` collection in Firestore.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Function to send a notification when a new document is added to the fcm_messages collection
exports.sendNotification = functions.firestore
  .document('fcm_messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.data();
      const { tokens, notification, data, userId } = messageData;

      if (!tokens || !Array.isArray(tokens) || tokens.length === 0) {
        console.log('No valid tokens provided for notification');
        await updateMessageStatus(context.params.messageId, 'failed', 'No valid tokens provided');
        return null;
      }

      // Prepare the message for FCM
      const message = {
        notification,
        data: data || {},
        tokens,
        android: {
          notification: {
            channelId: 'high_importance_channel',
            priority: 'high',
            sound: 'default',
            defaultSound: true,
            defaultVibrateTimings: true,
            defaultLightSettings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              contentAvailable: true,
            },
          },
        },
      };

      // Send the message to all tokens
      const response = await admin.messaging().sendMulticast(message);
      console.log(`Successfully sent message: ${response.successCount} successful, ${response.failureCount} failed`);
      
      // If some tokens failed, clean them up
      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx]);
          }
        });
        
        if (failedTokens.length > 0 && userId) {
          // Remove failed tokens from the user document
          await cleanupFailedTokens(userId, failedTokens);
        }
      }
      
      // Update the message status
      await updateMessageStatus(
        context.params.messageId, 
        'sent',
        `${response.successCount} successful, ${response.failureCount} failed`
      );

      return null;
    } catch (error) {
      console.error('Error sending notification:', error);
      await updateMessageStatus(context.params.messageId, 'failed', error.message);
      return null;
    }
  });

// Helper function to update the status of a message
async function updateMessageStatus(messageId, status, message) {
  await admin.firestore().collection('fcm_messages').doc(messageId).update({
    status,
    statusMessage: message,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// Helper function to remove failed tokens from a user
async function cleanupFailedTokens(userId, failedTokens) {
  const userRef = admin.firestore().collection('users').doc(userId);
  
  // Get the user document
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    console.log(`User ${userId} does not exist, can't clean up tokens`);
    return;
  }
  
  const userData = userDoc.data();
  const currentTokens = userData.deviceTokens || [];
  
  // Filter out the failed tokens
  const validTokens = currentTokens.filter(token => !failedTokens.includes(token));
  
  // Update the user document with valid tokens only
  await userRef.update({
    deviceTokens: validTokens,
    tokensUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  console.log(`Cleaned up ${failedTokens.length} invalid tokens for user ${userId}`);
}
