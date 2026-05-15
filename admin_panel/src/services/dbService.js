import {
    collection,
    getDocs,
    addDoc,
    updateDoc,
    deleteDoc,
    doc,
    query,
    orderBy,
    limit,
    onSnapshot,
} from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL, deleteObject } from "firebase/storage";
import { db, storage } from "../firebase/config";

// Generic CRUD service
export const dbService = {
    /**
     * @param {string} collectionName
     * @param {{ orderByField?: string, orderDirection?: 'asc'|'desc', limitCount?: number }} [options]
     */
    async getAll(collectionName, options = {}) {
        const { orderByField, orderDirection = "desc", limitCount } = options;
        const col = collection(db, collectionName);
        const constraints = [];
        if (orderByField) {
            constraints.push(
                orderBy(orderByField, orderDirection === "asc" ? "asc" : "desc")
            );
        }
        if (limitCount) {
            constraints.push(limit(limitCount));
        }
        const q =
            constraints.length > 0 ? query(col, ...constraints) : query(col);
        const querySnapshot = await getDocs(q);
        return querySnapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
    },

    async add(collectionName, data) {
        return await addDoc(collection(db, collectionName), data);
    },

    async update(collectionName, id, data) {
        const docRef = doc(db, collectionName, id);
        return await updateDoc(docRef, data);
    },

    async delete(collectionName, id) {
        const docRef = doc(db, collectionName, id);
        return await deleteDoc(docRef);
    },

    /**
     * Live document count for a collection (updates on create/delete).
     * @returns {() => void} Unsubscribe function.
     */
    subscribeCollectionSize(collectionName, onCount, onError) {
        return onSnapshot(
            collection(db, collectionName),
            (snapshot) => onCount(snapshot.size),
            onError || (() => {})
        );
    },

    /**
     * Live documents for a collection (updates on create/update/delete).
     * @param {string} collectionName
     * @param {(rows: object[]) => void} onData
     * @param {(e: Error) => void} [onError]
     * @param {{ orderByField?: string, orderDirection?: 'asc'|'desc', limitCount?: number }} [options]
     * @returns {() => void} Unsubscribe function.
     */
    subscribeCollectionDocs(collectionName, onData, onError, options = {}) {
        const { orderByField, orderDirection = "desc", limitCount } = options;
        const col = collection(db, collectionName);
        const constraints = [];
        if (orderByField) {
            constraints.push(
                orderBy(orderByField, orderDirection === "asc" ? "asc" : "desc")
            );
        }
        if (limitCount) {
            constraints.push(limit(limitCount));
        }
        const q =
            constraints.length > 0 ? query(col, ...constraints) : query(col);
        return onSnapshot(
            q,
            (snapshot) => {
                const rows = snapshot.docs.map((d) => ({
                    id: d.id,
                    ...d.data(),
                }));
                onData(rows);
            },
            onError || (() => {})
        );
    },

    /**
     * Live stats for `locations`: total docs + distinct non-empty `city` values.
     * @returns {() => void} Unsubscribe function.
     */
    subscribeLocationsStats(onStats, onError) {
        return onSnapshot(
            collection(db, "locations"),
            (snapshot) => {
                const cities = new Set();
                snapshot.docs.forEach((d) => {
                    const c = String(d.data()?.city || "").trim();
                    if (c) cities.add(c);
                });
                onStats({
                    count: snapshot.size,
                    distinctCities: cities.size,
                });
            },
            onError || (() => {})
        );
    },
};

// Storage service for .glb models
export const storageService = {
    async uploadFile(file, path) {
        const storageRef = ref(storage, path);
        await uploadBytes(storageRef, file);
        return await getDownloadURL(storageRef);
    },

    async deleteFile(url) {
        const storageRef = ref(storage, url);
        return await deleteObject(storageRef);
    }
};
