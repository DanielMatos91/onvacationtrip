
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// ==========================================================================
// HELPERS
// ==========================================================================

/**
 * Throws an HttpsError if the user is not authenticated.
 * @param {functions.https.CallableContext} context The context object.
 */
function ensureAuthenticated(context: functions.https.CallableContext) {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Você precisa estar autenticado."
        );
    }
}

/**
 * Throws an HttpsError if the user is not an admin.
 * @param {functions.https.CallableContext} context The context object.
 */
async function ensureAdmin(context: functions.https.CallableContext) {
    ensureAuthenticated(context);
    try {
        const userDoc = await db.collection("users").doc(context.auth!.uid).get();
        if (userDoc.data()?.role !== "admin") {
            throw new functions.https.HttpsError(
                "permission-denied",
                "Apenas administradores podem executar esta ação."
            );
        }
    } catch (error) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Falha ao verificar permissões de administrador."
        );
    }
}

// ==========================================================================
// AUTH TRIGGERS
// ==========================================================================

/**
 * (Helper) Creates a user document in Firestore for a new user.
 */
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
    const { uid, email } = user;
    // Note: Role and status are set to pending by default.
    // The `redeemInvite` function will update them.
    return db.collection("users").doc(uid).set({
        phoneOrEmail: email,
        role: "driver",
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
});

// ==========================================================================
// CALLABLE FUNCTIONS - ADMIN
// ==========================================================================

/**
 * Creates an invite code for a specific target user.
 * @param {{target: string, ttlDays: number}} data
 * @param {functions.https.CallableContext} context
 */
exports.adminCreateInvite = functions.https.onCall(async (data, context) => {
    await ensureAdmin(context);

    const { target, ttlDays = 30 } = data;
    if (!target) {
        throw new functions.https.HttpsError("invalid-argument", "O campo 'target' (email) é obrigatório.");
    }

    const code = `INV-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
    const expiresAt = admin.firestore.Timestamp.fromMillis(
        Date.now() + ttlDays * 24 * 60 * 60 * 1000
    );

    await db.collection("invites").doc(code).set({
        target: target,
        status: "active",
        expiresAt: expiresAt,
        createdBy: context.auth!.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        usedBy: null,
    });

    return { code };
});

/**
 * Creates a new ride.
 * @param {object} data Ride data.
 * @param {functions.https.CallableContext} context
 */
exports.adminCreateRide = functions.https.onCall(async (data, context) => {
    await ensureAdmin(context);

    // Basic validation
    if (!data.pickup || !data.dropoff || !data.datetime || !data.price || !data.passengerName) {
        throw new functions.https.HttpsError("invalid-argument", "Dados da corrida incompletos.");
    }

    const rideData = {
        ...data,
        status: "created",
        driverId: null,
        createdBy: context.auth!.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const rideRef = await db.collection("rides").add(rideData);
    return { rideId: rideRef.id };
});

/**
 * Assigns a ride to a driver.
 * @param {{rideId: string, driverId: string}} data
 * @param {functions.https.CallableContext} context
 */
exports.adminAssignRide = functions.https.onCall(async (data, context) => {
    await ensureAdmin(context);

    const { rideId, driverId } = data;
    if (!rideId || !driverId) {
        throw new functions.https.HttpsError("invalid-argument", "'rideId' e 'driverId' são obrigatórios.");
    }

    const rideRef = db.collection("rides").doc(rideId);
    const driverRef = db.collection("users").doc(driverId);

    const [rideDoc, driverDoc] = await Promise.all([rideRef.get(), driverRef.get()]);

    if (!rideDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Corrida não encontrada.");
    }
    if (!driverDoc.exists || driverDoc.data()?.role !== "driver") {
        throw new functions.https.HttpsError("not-found", "Motorista não encontrado ou inválido.");
    }

    await rideRef.update({
        driverId: driverId,
        status: "assigned",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
});


// ==========================================================================
// CALLABLE FUNCTIONS - DRIVER
// ==========================================================================

/**
 * Redeems an invite code, activating a driver's account.
 * @param {{code: string}} data
 * @param {functions.https.CallableContext} context
 */
exports.redeemInvite = functions.https.onCall(async (data, context) => {
    ensureAuthenticated(context);
    const uid = context.auth!.uid;
    const email = context.auth!.token.email;

    const { code } = data;
    if (!code) {
        throw new functions.https.HttpsError("invalid-argument", "O código do convite é obrigatório.");
    }

    const inviteRef = db.collection("invites").doc(code);
    const inviteDoc = await inviteRef.get();

    if (!inviteDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Convite inválido.");
    }

    const invite = inviteDoc.data()!;

    if (invite.status !== "active") {
        throw new functions.https.HttpsError("failed-precondition", `Convite já foi ${invite.status}.`);
    }

    if (invite.expiresAt.toMillis() < Date.now()) {
        throw new functions.https.HttpsError("failed-precondition", "Convite expirado.");
    }

    if (invite.target !== email) {
        throw new functions.https.HttpsError("permission-denied", "Este convite é para outro usuário.");
    }

    const userRef = db.collection("users").doc(uid);
    const driverProfileRef = db.collection("drivers").doc(uid);

    await db.runTransaction(async (transaction) => {
        transaction.update(userRef, { status: "approved", name: email });
        transaction.set(driverProfileRef, { updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        transaction.update(inviteRef, { status: "used", usedBy: uid });
    });

    return { success: true };
});

/**
 * Updates the status of a ride.
 * @param {{rideId: string, nextStatus: string}} data
 * @param {functions.https.CallableContext} context
 */
exports.driverUpdateRideStatus = functions.https.onCall(async (data, context) => {
    ensureAuthenticated(context);
    const uid = context.auth!.uid;

    const { rideId, nextStatus } = data;
    if (!rideId || !nextStatus) {
        throw new functions.https.HttpsError("invalid-argument", "'rideId' e 'nextStatus' são obrigatórios.");
    }

    const allowedTransitions: { [key: string]: string } = {
        assigned: "accepted",
        accepted: "arrived",
        arrived: "started",
        started: "finished",
    };

    const rideRef = db.collection("rides").doc(rideId);
    const rideDoc = await rideRef.get();

    if (!rideDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Corrida não encontrada.");
    }

    const ride = rideDoc.data()!;

    if (ride.driverId !== uid) {
        throw new functions.https.HttpsError("permission-denied", "Você não é o motorista desta corrida.");
    }

    if (allowedTransitions[ride.status] !== nextStatus) {
        throw new functions.https.HttpsError("failed-precondition",
            `Não é possível mudar do status '${ride.status}' para '${nextStatus}'.`);
    }

    await rideRef.update({
        status: nextStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log event
    await db.collection("ride_events").doc(rideId).collection("events").add({
        type: nextStatus,
        at: admin.firestore.FieldValue.serverTimestamp(),
        by: uid,
        payload: {},
    });

    return { success: true };
});

/**
 * Updates the driver's last known location.
 * @param {{lat: number, lng: number}} data
 * @param {functions.https.CallableContext} context
 */
exports.driverUpdateLocation = functions.https.onCall(async (data, context) => {
    ensureAuthenticated(context);
    const uid = context.auth!.uid;

    const { lat, lng } = data;
    if (typeof lat !== "number" || typeof lng !== "number") {
        throw new functions.https.HttpsError("invalid-argument", "'lat' e 'lng' são obrigatórios e devem ser números.");
    }

    const locationData = {
        lat: lat,
        lng: lng,
        at: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Update driver's main profile
    await db.collection("drivers").doc(uid).update({
        lastLocation: locationData,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Optional: Log to active ride
    const activeRideQuery = await db.collection("rides")
        .where("driverId", "==", uid)
        .where("status", "in", ["accepted", "arrived", "started"])
        .limit(1)
        .get();

    if (!activeRideQuery.empty) {
        const rideId = activeRideQuery.docs[0].id;
        await db.collection("ride_events").doc(rideId).collection("events").add({
            type: "location",
            at: locationData.at,
            by: uid,
            payload: locationData,
        });
    }

    return { success: true };
});

