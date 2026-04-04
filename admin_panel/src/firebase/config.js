import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
    apiKey: "AIzaSyDSILscLjTFgsPYNoTNOddcvOqqQttEgPY",
    authDomain: "ceylon-trails-bec69.firebaseapp.com",
    projectId: "ceylon-trails-bec69",
    storageBucket: "ceylon-trails-bec69.firebasestorage.app",
    messagingSenderId: "339553065196",
    appId: "1:339553065196:web:83d9a730093aa521156dc9",
    measurementId: "G-VWZWH4N5WT"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
