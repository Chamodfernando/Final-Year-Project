import {
    collection,
    getDocs,
    addDoc,
    updateDoc,
    deleteDoc,
    doc,
    query,
    orderBy
} from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL, deleteObject } from "firebase/storage";
import { db, storage } from "../firebase/config";

// Generic CRUD service
export const dbService = {
    async getAll(collectionName) {
        const q = query(collection(db, collectionName));
        const querySnapshot = await getDocs(q);
        return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
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
    }
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
