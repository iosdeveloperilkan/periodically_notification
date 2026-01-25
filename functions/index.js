const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

/**
 * Scheduled Cloud Function that runs daily at specified time (Europe/Istanbul)
 * Sends daily content to all users via FCM topic
 *
 * Schedule: Every day at 02:40 AM Europe/Istanbul timezone
 * To change time, modify the schedule property below
 */
exports.sendDailyWidgetContent = onSchedule(
    {
      schedule: "40 2 * * *", // 2:40 AM daily (Europe/Istanbul timezone)
      timeZone: "Europe/Istanbul",
      memory: "256MiB",
      timeoutSeconds: 540,
    },
    async (event) => {
      const functions = require("firebase-functions");
      functions.logger.info(
          "Daily widget content scheduler triggered",
          {timestamp: new Date().toISOString()},
      );

      try {
        // Step 1: Read current state to get nextOrder
        const stateRef = db.collection("daily_state").doc("current");
        const stateDoc = await stateRef.get();

        if (!stateDoc.exists) {
          functions.logger.error("daily_state/current document not found");
          return {success: false, error: "State document not found"};
        }

        const state = stateDoc.data();
        const nextOrder = state.nextOrder || 1;

        functions.logger.info(`Looking for item with order: ${nextOrder}`);

        // Step 2: Find item with matching order
        const itemsQuery = await db
            .collection("daily_items")
            .where("order", "==", nextOrder)
            .where("sent", "==", false)
            .limit(1)
            .get();

        if (itemsQuery.empty) {
          functions.logger.warn(
              `No unsent item found with order ${nextOrder}`,
          );
          return {
            success: false,
            error: `No unsent item found with order ${nextOrder}`,
          };
        }

        const itemDoc = itemsQuery.docs[0];
        const itemData = itemDoc.data();
        const itemId = itemDoc.id;

        functions.logger.info(`Found item: ${itemId}`, {
          title: itemData.title,
          order: itemData.order,
        });

        // Step 3: Use transaction to atomically update item and state
        await db.runTransaction(async (transaction) => {
          // Mark item as sent
          transaction.update(itemDoc.ref, {
            sent: true,
            sentAt: new Date(),
          });

          // Increment nextOrder
          const newNextOrder = nextOrder + 1;
          transaction.update(stateRef, {
            nextOrder: newNextOrder,
            lastSentAt: new Date(),
            lastSentItemId: itemId,
          });

          functions.logger.info(
              `Transaction prepared: item marked as sent, ` +
              `nextOrder=${newNextOrder}`,
          );
        });

        // Step 4: Prepare FCM messages
        const notificationTitle = "Günün İçeriği";
        const notificationBody = itemData.title || "Yeni içerik hazır";

        // Visible notification (guaranteed delivery)
        const notificationMessage = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            type: "DAILY_WIDGET",
            order: String(itemData.order),
            itemId: itemId,
            docPath: `daily_items/${itemId}`,
            title: itemData.title || "",
            body: itemData.body || "",
            updatedAt: new Date().toISOString(),
          },
          topic: "daily_widget_all",
          android: {
            priority: "high",
            notification: {
              channelId: "daily_widget_channel",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: notificationTitle,
                  body: notificationBody,
                },
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        // Optional: Silent data-only message for widget auto-update
        const dataOnlyMessage = {
          data: {
            type: "DAILY_WIDGET_UPDATE",
            order: String(itemData.order),
            itemId: itemId,
            docPath: `daily_items/${itemId}`,
            title: itemData.title || "",
            body: itemData.body || "",
            updatedAt: new Date().toISOString(),
          },
          topic: "daily_widget_all",
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "5", // Low priority for silent notification
            },
            payload: {
              aps: {
                "content-available": 1,
              },
            },
          },
        };

        // Step 5: Send both messages
        const results = await Promise.allSettled([
          messaging.send(notificationMessage),
          messaging.send(dataOnlyMessage),
        ]);

        const notificationResult = results[0];
        const dataOnlyResult = results[1];

        if (notificationResult.status === "fulfilled") {
          functions.logger.info(
              "Visible notification sent successfully",
              {messageId: notificationResult.value},
          );
        } else {
          functions.logger.error(
              "Failed to send visible notification",
              {error: notificationResult.reason},
          );
        }

        if (dataOnlyResult.status === "fulfilled") {
          functions.logger.info(
              "Data-only message sent successfully",
              {messageId: dataOnlyResult.value},
          );
        } else {
          functions.logger.warn(
              "Failed to send data-only message (non-critical)",
              {error: dataOnlyResult.reason},
          );
        }

        return {
          success: true,
          itemId: itemId,
          order: itemData.order,
          notificationSent: notificationResult.status === "fulfilled",
          dataOnlySent: dataOnlyResult.status === "fulfilled",
        };
      } catch (error) {
        functions.logger.error("Error in sendDailyWidgetContent", {
          error: error.message,
          stack: error.stack,
        });
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

/**
 * Helper function to manually trigger daily content send (for testing)
 * Can be called via HTTP or from Firebase Console
 */
exports.manualSendDailyContent = onCall(
    {
      region: "us-central1",
    },
    async (request) => {
      // Optional: Add authentication check here
      // if (!context.auth) {
      //   throw new functions.https.HttpsError(
      //       'unauthenticated',
      //       'Must be authenticated'
      //   );
      // }

      const functions = require("firebase-functions");
      const logger = require("firebase-functions/logger");
      logger.info("Manual send triggered");

      // Reuse the same logic as scheduled function
      // For simplicity, we'll call the scheduled function logic inline
      // In production, extract to a shared function

      try {
        const stateRef = db.collection("daily_state").doc("current");
        const stateDoc = await stateRef.get();

        if (!stateDoc.exists) {
          throw new functions.https.HttpsError(
              "not-found",
              "State document not found",
          );
        }

        const state = stateDoc.data();
        const nextOrder = state.nextOrder || 1;

        const itemsQuery = await db
            .collection("daily_items")
            .where("order", "==", nextOrder)
            .where("sent", "==", false)
            .limit(1)
            .get();

        if (itemsQuery.empty) {
          throw new functions.https.HttpsError(
              "not-found",
              `No unsent item found with order ${nextOrder}`,
          );
        }

        const itemDoc = itemsQuery.docs[0];
        const itemData = itemDoc.data();
        const itemId = itemDoc.id;

        await db.runTransaction(async (transaction) => {
          transaction.update(itemDoc.ref, {
            sent: true,
            sentAt: new Date(),
          });
          transaction.update(stateRef, {
            nextOrder: nextOrder + 1,
            lastSentAt: new Date(),
            lastSentItemId: itemId,
          });
        });

        const notificationMessage = {
          notification: {
            title: "Günün İçeriği",
            body: itemData.title || "Yeni içerik hazır",
          },
          data: {
            type: "DAILY_WIDGET",
            order: String(itemData.order),
            itemId: itemId,
            docPath: `daily_items/${itemId}`,
            title: itemData.title || "",
            body: itemData.body || "",
            updatedAt: new Date().toISOString(),
          },
          topic: "daily_widget_all",
        };

        const messageId = await messaging.send(notificationMessage);

        return {
          success: true,
          itemId: itemId,
          order: itemData.order,
          messageId: messageId,
        };
      } catch (error) {
        logger.error("Error in manualSendDailyContent", error);
        throw new functions.https.HttpsError(
            "internal",
            error.message,
        );
      }
    },
);
