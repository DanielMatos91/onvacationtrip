import {initializeApp} from "firebase/app";
import {getAuth, signInWithEmailAndPassword} from "firebase/auth";
import {getFunctions, httpsCallable, connectFunctionsEmulator} from "firebase/functions";

function required(name) {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
}

function getFunctionsForEnv(app) {
    const functions = getFunctions(app);
    const emulatorFlag = process.argv.includes("--emulator");
    const hostPortEnv = process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST;

    if (emulatorFlag || hostPortEnv) {
        const hostPort = hostPortEnv || "127.0.0.1:5001";
        const [host, portString] = hostPort.split(":");
        const port = Number(portString);
        if (!host || Number.isNaN(port)) {
            throw new Error(`Invalid FIREBASE_FUNCTIONS_EMULATOR_HOST value: ${hostPort}`);
        }
        connectFunctionsEmulator(functions, host, port);
    }

    return functions;
}

async function main() {
    const apiKey = required("FIREBASE_API_KEY");
    const authDomain = required("FIREBASE_AUTH_DOMAIN");
    const projectId = required("FIREBASE_PROJECT_ID");
    const appId = required("FIREBASE_APP_ID");
    const adminEmail = required("ADMIN_EMAIL");
    const adminPassword = required("ADMIN_PASSWORD");
    const bootstrapKey = required("BOOTSTRAP_KEY");

    const app = initializeApp({
        apiKey,
        authDomain,
        projectId,
        appId,
    });

    const auth = getAuth(app);
    const functions = getFunctionsForEnv(app);

    await signInWithEmailAndPassword(auth, adminEmail, adminPassword);
    const callable = httpsCallable(functions, "bootstrapAdmin");
    await callable({bootstrapKey});

    console.log("OK");
}

main().catch((err) => {
    console.error("Bootstrap failed:", err?.message || err);
    if (err?.stack) {
        console.error(err.stack);
    }
    process.exit(1);
});
