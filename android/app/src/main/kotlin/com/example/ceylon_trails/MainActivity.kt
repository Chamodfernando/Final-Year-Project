package com.example.ceylon_trails

import java.io.File
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    companion object {
        /** Must match [CeylonGlbCacheManager.key] in Dart. */
        private const val GLB_CACHE_FOLDER = "ceylon_glb_models"
        private const val GLB_CACHE_DB_PREFIX = "ceylon_glb_models.db"
    }

    override fun onDestroy() {
        // Best-effort native cleanup when task is finished / swiped from recents.
        // flutter_cache_manager stores blobs as hashed names (not .glb), under this folder.
        if (isFinishing && !isChangingConfigurations) {
            deleteRecursive(File(cacheDir, GLB_CACHE_FOLDER))
            deleteRecursive(File(externalCacheDir, GLB_CACHE_FOLDER))
            deleteGlbCacheDbFiles(filesDir)
        }
        super.onDestroy()
    }

    private fun deleteRecursive(file: File?) {
        if (file == null || !file.exists()) return
        if (file.isDirectory) {
            file.listFiles()?.forEach { deleteRecursive(it) }
        }
        runCatching { file.delete() }
    }

    private fun deleteGlbCacheDbFiles(dir: File?) {
        if (dir == null || !dir.isDirectory) return
        dir.listFiles()?.forEach { child ->
            if (child.name == GLB_CACHE_DB_PREFIX ||
                child.name.startsWith("$GLB_CACHE_DB_PREFIX-")
            ) {
                runCatching { child.delete() }
            }
        }
    }
}
