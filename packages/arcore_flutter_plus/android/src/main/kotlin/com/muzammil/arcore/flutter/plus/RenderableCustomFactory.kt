package com.muzammil.arcore.flutter.plus

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import com.muzammil.arcore.flutter.plus.flutter_models.FlutterArCoreNode
import com.google.ar.sceneform.assets.RenderableSource
import com.google.ar.sceneform.rendering.Material
import com.google.ar.sceneform.rendering.ModelRenderable
import com.google.ar.sceneform.rendering.Renderable
import com.google.ar.sceneform.rendering.ViewRenderable
import java.util.concurrent.CompletableFuture
import java.util.function.Consumer

import android.widget.RelativeLayout.LayoutParams;

typealias MaterialHandler = (Material?, Throwable?) -> Unit
typealias RenderableHandler = (Renderable?, Throwable?) -> Unit

class RenderableCustomFactory {

    companion object {

        val TAG = "RenderableCustomFactory"

        private val modelCacheLock = Any()
        private val modelFutures = java.util.concurrent.ConcurrentHashMap<String, CompletableFuture<ModelRenderable>>()

        /** Start loading a reference model so first placement is faster (shared with [makeRenderable]). */
        fun prefetchReferenceModel(context: Context, object3DFileName: String?, objectUrl: String?) {
            val uri = object3DFileName?.trim()?.takeIf { it.isNotEmpty() }
                ?: objectUrl?.trim()?.takeIf { it.isNotEmpty() }
                ?: return
            loadReferenceModelFuture(context.applicationContext, uri)
        }

        private fun loadReferenceModelFuture(context: Context, uriString: String): CompletableFuture<ModelRenderable> {
            synchronized(modelCacheLock) {
                val existing = modelFutures[uriString]
                if (existing != null) {
                    if (!existing.isDone) return existing
                    if (!existing.isCompletedExceptionally) return existing
                    modelFutures.remove(uriString)
                }
                val fresh = startModelBuild(context, uriString)
                modelFutures[uriString] = fresh
                fresh.whenComplete { _, u ->
                    if (u != null) {
                        synchronized(modelCacheLock) {
                            if (modelFutures[uriString] === fresh) {
                                modelFutures.remove(uriString)
                            }
                        }
                    }
                }
                return fresh
            }
        }

        private fun startModelBuild(context: Context, uriString: String): CompletableFuture<ModelRenderable> {
            val lower = uriString.lowercase()
            val isHttp = uriString.startsWith("http://") || uriString.startsWith("https://")
            return when {
                isHttp -> buildHttpModel(context, uriString, lower.endsWith(".glb"))
                lower.endsWith(".glb") || lower.endsWith(".gltf") -> buildLocalGlbGltf(context, uriString, lower.endsWith(".glb"))
                else -> buildLocalSfbOrLegacy(context, uriString)
            }
        }

        private fun buildLocalGlbGltf(context: Context, uriString: String, isGlb: Boolean): CompletableFuture<ModelRenderable> {
            val renderableSourceBuilder = RenderableSource.builder()
                .setSource(
                    context,
                    Uri.parse(uriString),
                    if (isGlb) RenderableSource.SourceType.GLB else RenderableSource.SourceType.GLTF2
                )
                .setRecenterMode(RenderableSource.RecenterMode.ROOT)
            return ModelRenderable.builder()
                .setSource(context, renderableSourceBuilder.build())
                .setRegistryId(uriString)
                .build()
        }

        private fun buildLocalSfbOrLegacy(context: Context, uriString: String): CompletableFuture<ModelRenderable> {
            return ModelRenderable.builder()
                .setSource(context, Uri.parse(uriString))
                .setRegistryId(uriString)
                .build()
        }

        private fun buildHttpModel(context: Context, url: String, isGlb: Boolean): CompletableFuture<ModelRenderable> {
            val renderableSourceBuilder = RenderableSource.builder()
            if (isGlb) {
                renderableSourceBuilder
                    .setSource(context, Uri.parse(url), RenderableSource.SourceType.GLB)
                    .setScale(0.5f)
                    .setRecenterMode(RenderableSource.RecenterMode.ROOT)
            } else {
                renderableSourceBuilder
                    .setSource(context, Uri.parse(url), RenderableSource.SourceType.GLTF2)
                    .setScale(0.5f)
                    .setRecenterMode(RenderableSource.RecenterMode.ROOT)
            }
            return ModelRenderable.builder()
                .setSource(context, renderableSourceBuilder.build())
                .setRegistryId(url)
                .build()
        }

        @SuppressLint("ShowToast")
        fun makeRenderable(context: Context, flutterArCoreNode: FlutterArCoreNode, handler: RenderableHandler) {

            if (flutterArCoreNode.dartType == "ArCoreReferenceNode") {

                val url = flutterArCoreNode.objectUrl
                val localObject = flutterArCoreNode.object3DFileName
                val uriString = localObject?.trim()?.takeIf { it.isNotEmpty() }
                    ?: url?.trim()?.takeIf { it.isNotEmpty() }
                if (uriString != null) {
                    loadReferenceModelFuture(context.applicationContext, uriString)
                        .thenAccept { renderable -> handler(renderable, null) }
                        .exceptionally { throwable ->
                            Log.e(TAG, "Unable to load reference Renderable.", throwable)
                            handler(null, throwable)
                            null
                        }
                } else {
                    handler(null, IllegalArgumentException("ArCoreReferenceNode requires object3DFileName or objectUrl"))
                }

            } else {

                if (flutterArCoreNode.image != null) {
                    val image = ImageView(context);
                    image.layoutParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
                    val bmp = BitmapFactory.decodeByteArray(flutterArCoreNode.image.bytes, 0, flutterArCoreNode.image.bytes.size)

                    image.setImageBitmap(Bitmap.createScaledBitmap(bmp, flutterArCoreNode.image.width,
                            flutterArCoreNode.image.height, false))

                    ViewRenderable.builder().setView(context, image)
                            .build()
                            .thenAccept(Consumer { renderable: ViewRenderable -> handler(renderable, null) })
                            .exceptionally { throwable ->
                                Log.e(TAG, "Unable to load image renderable.", throwable);
                                handler(null, throwable)
                                return@exceptionally null
                            }
                } else {
                    makeMaterial(context, flutterArCoreNode) { material, throwable ->
                        if (throwable != null) {
                            handler(null, throwable)
                            return@makeMaterial
                        }
                        if (material == null) {
                            handler(null, null)
                            return@makeMaterial
                        }
                        try {
                            if (flutterArCoreNode.shape?.dartType == "ArCoreCartoon") {
                                val textView = TextView(context)
                                textView.text = when (flutterArCoreNode.shape.model) {
                                    "robot" -> "🤖"
                                    "ghost" -> "👻"
                                    "alien" -> "👽"
                                    "fox" -> "🦊"
                                    "duck" -> "🦆"
                                    else -> "🤖"
                                }
                                textView.textSize = 100f
                                ViewRenderable.builder().setView(context, textView)
                                        .build()
                                        .thenAccept { renderable ->
                                            handler(renderable, null)
                                        }
                                        .exceptionally { throwable ->
                                            Log.e(TAG, "Unable to load cartoon renderable.", throwable)
                                            handler(null, throwable)
                                            return@exceptionally null
                                        }
                            } else {
                                val renderable = flutterArCoreNode.shape?.buildShape(material)
                                handler(renderable, null)
                            }
                        } catch (ex: Exception) {
                            Log.e(TAG, "renderable error ${ex}")
                            handler(null, ex)
                            Toast.makeText(context, ex.toString(), Toast.LENGTH_LONG)
                        }
                    }


                }

            }
        }

        private fun makeMaterial(context: Context, flutterArCoreNode: FlutterArCoreNode, handler: MaterialHandler) {
//            val texture = flutterArCoreNode.shape?.materials?.first()?.texture
            val textureBytes = flutterArCoreNode.shape?.materials?.first()?.textureBytes
            val color = flutterArCoreNode.shape?.materials?.first()?.color
            if (textureBytes != null) {
//                val isPng = texture.endsWith("png")
                val isPng = true

                val builder = com.google.ar.sceneform.rendering.Texture.builder();
//                builder.setSource(context, Uri.parse(texture))
                builder.setSource(BitmapFactory.decodeByteArray(textureBytes, 0, textureBytes.size))
                builder.build().thenAccept { texture ->
                    MaterialCustomFactory.makeWithTexture(context, texture, isPng, flutterArCoreNode.shape.materials[0])?.thenAccept { material ->
                        handler(material, null)
                    }?.exceptionally { throwable ->
                        Log.e(TAG, "texture error ${throwable}")
                        handler(null, throwable)
                        return@exceptionally null
                    }
                }
            } else if (color != null) {
                MaterialCustomFactory.makeWithColor(context, flutterArCoreNode.shape.materials[0])
                        ?.thenAccept { material: Material ->
                            handler(material, null)
                        }?.exceptionally { throwable ->
                            Log.e(TAG, "material error ${throwable}")
                            handler(null, throwable)
                            return@exceptionally null
                        }
            } else {
                handler(null, null)
            }
        }
    }
}
