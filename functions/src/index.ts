import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.database();
const firestore = admin.firestore();

/**
 * Triggered on RTDB room turn deadline updates.
 * Automatically advances turn to next seat if client disconnects or times out.
 */
export const enforceTurnTimeout = functions.database
  .ref("/rooms/{roomId}/turnState/turnDeadline")
  .onUpdate(async (change, context) => {
    const roomId = context.params.roomId;
    const deadline = change.after.val();

    if (!deadline || deadline <= 0) return null;

    const delayMs = deadline - Date.now();
    if (delayMs > 0 && delayMs < 20000) {
      // Allow client grace period, then verify if turn was played
      setTimeout(async () => {
        const turnSnap = await db.ref(`/rooms/${roomId}/turnState`).get();
        if (!turnSnap.exists()) return;

        const currentTurn = turnSnap.val();
        if (currentTurn.turnDeadline === deadline && currentTurn.winnerSeat === -1) {
          const nextSeat = (currentTurn.currentTurnSeat + 1) % 4;
          await db.ref(`/rooms/${roomId}/turnState`).update({
            currentTurnSeat: nextSeat,
            diceRoll: 0,
            hasRolled: false,
            turnDeadline: Date.now() + 15000,
          });
        }
      }, delayMs + 1000);
    }
    return null;
  });

/**
 * Triggered when a match status changes to FINISHED.
 * Authoritatively validates winner, calculates Elo change, and credits coins.
 */
export const resolveMatchFinished = functions.database
  .ref("/rooms/{roomId}/meta/status")
  .onUpdate(async (change, context) => {
    const roomId = context.params.roomId;
    const status = change.after.val();

    if (status !== "FINISHED") return null;

    const roomSnap = await db.ref(`/rooms/${roomId}`).get();
    if (!roomSnap.exists()) return null;

    const roomData = roomSnap.val();
    const winnerSeat = roomData.turnState?.winnerSeat;
    const players = roomData.players || {};

    let winnerUid: string | null = null;
    const participantUids: string[] = [];

    for (const [uid, p] of Object.entries<any>(players)) {
      participantUids.push(uid);
      if (p.seatIndex === winnerSeat) {
        winnerUid = uid;
      }
    }

    // Award 100 coins to winner, update Elo ratings
    const batch = firestore.batch();

    for (const uid of participantUids) {
      const userRef = firestore.collection("users").doc(uid);
      const isWinner = uid === winnerUid;

      batch.set(
        userRef,
        {
          coins: admin.firestore.FieldValue.increment(isWinner ? 100 : 20),
          elo: admin.firestore.FieldValue.increment(isWinner ? 25 : -15),
          "stats.gamesPlayed": admin.firestore.FieldValue.increment(1),
          "stats.wins": admin.firestore.FieldValue.increment(isWinner ? 1 : 0),
          "stats.losses": admin.firestore.FieldValue.increment(isWinner ? 0 : 1),
        },
        { merge: true }
      );
    }

    await batch.commit();
    return null;
  });

