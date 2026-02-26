const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Triggered when a new alert is pushed to /users/{uid}/alerts/{alertId}
 * Checks if the alert is high priority, fetches user's contacts' FCM tokens,
 * and dispatches push notifications.
 */
exports.onCriticalAlertDetectedFCM = functions.database
    .ref("/users/{uid}/alerts/{alertId}")
    .onCreate(async (snapshot, context) => {
      const alertData = snapshot.val();
      const uid = context.params.uid;

      // Only alert on critical sounds
      if (alertData.type !== "high" && alertData.type !== "emergency") return null;

      console.log(`Processing critical alert [${context.params.alertId}] for user ${uid}. Label: ${alertData.label}`);

      // Fetch the emergency contacts for this specific user
      const contactsSnap = await admin.database().ref(`/users/${uid}/contacts`).once("value");

      if (!contactsSnap.exists() || contactsSnap.val() === null) {
        console.log(`User ${uid} has no contacts configured. Skipping FCM.`);
        return null;
      }

      const contactsObj = contactsSnap.val();
      const contacts = Object.values(contactsObj);

      // Extract valid FCM tokens from the contacts that have them linked
      const fcmTokens = contacts
          .map((c) => c.fcmToken)
          .filter((token) => token && token.trim().length > 0);

      if (fcmTokens.length === 0) {
        console.log(`User ${uid} has contacts, but none have FCM tokens linked. Skipping FCM.`);
        return null;
      }

      console.log(`Found ${fcmTokens.length} linked FCM tokens for user ${uid}. Dispatching Push...`);

      // Construct the FCM Payload
      const payload = {
        notification: {
          title: "HearAlert EMERGENCY",
          body: `A critical sound (${alertData.label}) was detected near your contact. Please check on them!`,
        },
        data: {
          alertId: context.params.alertId,
          label: alertData.label,
          type: alertData.type,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      // Dispatch Push Notification to all extracted tokens
      try {
        const response = await admin.messaging().sendToDevice(fcmTokens, payload);
        console.log(`Successfully dispatched FCM to ${response.successCount} devices.`);
        if (response.failureCount > 0) {
          console.error(`Failed to deliver to ${response.failureCount} devices.`);
        }
      } catch (err) {
        console.error("Error dispatching FCM Push Notification:", err);
      }

      return null;
    });
