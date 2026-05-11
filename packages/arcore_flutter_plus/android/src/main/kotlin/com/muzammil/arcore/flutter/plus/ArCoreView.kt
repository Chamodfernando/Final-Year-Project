package com.muzammil.arcore.flutter.plus

import android.app.Activity
import android.app.Application
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.SystemClock
import android.util.Log
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.Toast
import com.muzammil.arcore.flutter.plus.flutter_models.FlutterArCoreHitTestResult
import com.muzammil.arcore.flutter.plus.flutter_models.FlutterArCoreNode
import com.muzammil.arcore.flutter.plus.flutter_models.FlutterArCorePose
import com.muzammil.arcore.flutter.plus.models.RotatingNode
import com.muzammil.arcore.flutter.plus.utils.ArCoreUtils
import com.google.ar.core.*
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.UnavailableException
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException
import com.google.ar.sceneform.*
import com.google.ar.sceneform.math.Quaternion
import com.google.ar.sceneform.math.Vector3
import com.google.ar.sceneform.rendering.ModelRenderable
import com.google.ar.sceneform.rendering.Texture
import com.google.ar.sceneform.ux.AugmentedFaceNode
import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

import android.graphics.Bitmap
import android.os.Environment
import android.view.PixelCopy
import android.os.HandlerThread
import android.content.ContextWrapper
import java.io.FileOutputStream
import java.io.File
import java.io.IOException
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import kotlin.math.sqrt

class ArCoreView(val activity: Activity, context: Context, messenger: BinaryMessenger, id: Int, private val isAugmentedFaces: Boolean, private val debug: Boolean) : PlatformView, MethodChannel.MethodCallHandler {
    private val methodChannel: MethodChannel = MethodChannel(messenger, "arcore_flutter_plus_$id")
    //       private val activity: Activity = (context.applicationContext as FlutterApplication).currentActivity
    lateinit var activityLifecycleCallbacks: Application.ActivityLifecycleCallbacks
    private var installRequested: Boolean = false
    private var mUserRequestedInstall = true
    private val TAG: String = ArCoreView::class.java.name
    private var arSceneView: ArSceneView? = null
    private val gestureDetector: GestureDetector
    private val RC_PERMISSIONS = 0x123
    private var sceneUpdateListener: Scene.OnUpdateListener
    private var faceSceneUpdateListener: Scene.OnUpdateListener

    //AUGMENTEDFACE
    private var faceRegionsRenderable: ModelRenderable? = null
    private var faceMeshTexture: Texture? = null
    private val faceNodeMap = HashMap<AugmentedFace, AugmentedFaceNode>()
    private var planeColor: com.google.ar.sceneform.rendering.Color? = null
    /** Throttle fallback plane events so Flutter still gets progress when [Frame.getUpdatedTrackables] is empty. */
    private var lastPlaneFallbackEmitMs: Long = 0L

    /** Cap how often we cross the Flutter bridge for plane updates (scanning phase only). */
    private var lastPlaneEmitToFlutterMs: Long = 0L

    /**
     * After a model is placed, hide plane mesh and stop forwarding plane events to Flutter so the
     * platform channel and plane overdraw do not tank framerate.
     */
    private var sceneLightweightMode: Boolean = false

    /**
     * Anchor created from the actual [HitResult] on tap, consumed when Flutter adds the model.
     * Using [HitResult.createAnchor] ties the object to the plane / instant point so it does not
     * slide when ARCore refines the map (unlike [Session.createAnchor] from pose alone).
     */
    private var pendingPlacementAnchor: Anchor? = null

    init {
        methodChannel.setMethodCallHandler(this)
        // Use the Activity context so the GL surface + camera pipeline match ARCore expectations.
        arSceneView = ArSceneView(activity)
        // Set up a tap gesture detector.
        gestureDetector = GestureDetector(
                activity,
                object : GestureDetector.SimpleOnGestureListener() {
                    override fun onSingleTapUp(e: MotionEvent): Boolean {
                        onSingleTap(e)
                        return true
                    }

                    override fun onDown(e: MotionEvent): Boolean {
                        return true
                    }
                })

        sceneUpdateListener = Scene.OnUpdateListener { _ ->
            val frame = arSceneView?.arFrame ?: return@OnUpdateListener

            if (frame.camera.trackingState != TrackingState.TRACKING) {
                return@OnUpdateListener
            }

            if (sceneLightweightMode) {
                return@OnUpdateListener
            }

            val session = arSceneView?.session ?: return@OnUpdateListener
            val nowMs = SystemClock.uptimeMillis()

            fun emitPlane(plane: Plane) {
                if (nowMs - lastPlaneEmitToFlutterMs < 100L) {
                    return
                }
                lastPlaneEmitToFlutterMs = nowMs
                val pose = plane.centerPose
                val map: HashMap<String, Any> = HashMap<String, Any>()
                map["type"] = plane.type.ordinal
                map["centerPose"] = FlutterArCorePose(pose.translation, pose.rotationQuaternion).toHashMap()
                map["extentX"] = plane.extentX
                map["extentZ"] = plane.extentZ
                methodChannel.invokeMethod("onPlaneDetected", map)
            }

            // Fast path: planes updated this frame (original plugin behaviour).
            val updated = frame.getUpdatedTrackables(Plane::class.java)
            var emitted = false
            for (plane in updated) {
                if (plane.trackingState == TrackingState.TRACKING) {
                    emitPlane(plane)
                    emitted = true
                }
            }

            // Many devices / scenes rarely populate "updated" planes; without this,
            // Flutter never receives onPlaneDetected even while the grid is visible.
            if (!emitted && nowMs - lastPlaneFallbackEmitMs >= 180L) {
                val best = session.getAllTrackables(Plane::class.java)
                        .asSequence()
                        .filter { it.trackingState == TrackingState.TRACKING && it.subsumedBy == null }
                        .maxByOrNull { it.extentX * it.extentZ }
                if (best != null) {
                    lastPlaneFallbackEmitMs = nowMs
                    emitPlane(best)
                }
            }
        }

        faceSceneUpdateListener = Scene.OnUpdateListener { frameTime ->
            run {
                //                if (faceRegionsRenderable == null || faceMeshTexture == null) {
                if (faceMeshTexture == null) {
                    return@OnUpdateListener
                }

                val faceList = arSceneView?.session?.getAllTrackables(AugmentedFace::class.java)

                faceList?.let {
                    // Make new AugmentedFaceNodes for any new faces.
                    for (face in faceList) {
                        if (!faceNodeMap.containsKey(face)) {
                            val faceNode = AugmentedFaceNode(face)
                            faceNode.setParent(arSceneView?.scene)
                            faceNode.faceRegionsRenderable = faceRegionsRenderable
                            faceNode.faceMeshTexture = faceMeshTexture
                            faceNodeMap[face] = faceNode
                        }
                    }

                    // Remove any AugmentedFaceNodes associated with an AugmentedFace that stopped tracking.
                    val iter = faceNodeMap.iterator()
                    while (iter.hasNext()) {
                        val entry = iter.next()
                        val face = entry.key
                        if (face.trackingState == TrackingState.STOPPED) {
                            val faceNode = entry.value
                            faceNode.setParent(null)
                            iter.remove()
                        }
                    }
                }
            }
        }

        // Lastly request CAMERA permission which is required by ARCore.
        ArCoreUtils.requestCameraPermission(activity, RC_PERMISSIONS)
        setupLifeCycle(context)
    }

    fun debugLog(message: String) {
        if (debug) {
            Log.i(TAG, message)
        }
    }


    fun loadMesh(textureBytes: ByteArray?) {
        // Load the face regions renderable.
        // This is a skinned model that renders 3D objects mapped to the regions of the augmented face.
        /*ModelRenderable.builder()
                .setSource(activity, Uri.parse("fox_face.sfb"))
                .build()
                .thenAccept { modelRenderable ->
                    faceRegionsRenderable = modelRenderable;
                    modelRenderable.isShadowCaster = false;
                    modelRenderable.isShadowReceiver = false;
                }*/

        // Load the face mesh texture.
        //                .setSource(activity, Uri.parse("fox_face_mesh_texture.png"))
        Texture.builder()
                .setSource(BitmapFactory.decodeByteArray(textureBytes, 0, textureBytes!!.size))
                .build()
                .thenAccept { texture -> faceMeshTexture = texture }
    }


    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                arScenViewInit(call, result, activity)
            }
            "addArCoreNode" -> {
                debugLog(" addArCoreNode")
                val map = call.arguments as HashMap<String, Any>
                val flutterNode = FlutterArCoreNode(map);
                onAddNode(flutterNode, result)
            }
            "addArCoreNodeWithAnchor" -> {
                debugLog(" addArCoreNode")
                val map = call.arguments as HashMap<String, Any>
                val flutterNode = FlutterArCoreNode(map)
                addNodeWithAnchor(flutterNode, result)
            }
            "prefetchReferenceModel" -> {
                val fileName = call.argument<String>("object3DFileName")
                val url = call.argument<String>("objectUrl")
                RenderableCustomFactory.prefetchReferenceModel(activity.applicationContext, fileName, url)
                result.success(null)
            }
            "setLightweightSceneMode" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setLightweightSceneMode(enabled)
                result.success(null)
            }
            "removeARCoreNode" -> {
                debugLog(" removeARCoreNode")
                val map = call.arguments as HashMap<String, Any>
                removeNode(map["nodeName"] as String, result)
            }
            "updateNodeTransform" -> {
                updateNodeTransform(call, result)
            }
            "positionChanged" -> {
                debugLog(" positionChanged")

            }
            "rotationChanged" -> {
                debugLog(" rotationChanged")
                updateRotation(call, result)

            }
            "updateMaterials" -> {
                debugLog(" updateMaterials")
                updateMaterials(call, result)

            }
            "takeScreenshot" -> {
                debugLog(" takeScreenshot")
                takeScreenshot(call, result)

            }
            "loadMesh" -> {
                val map = call.arguments as HashMap<String, Any>
                val textureBytes = map["textureBytes"] as ByteArray
                loadMesh(textureBytes)
            }
            "dispose" -> {
                debugLog("Disposing ARCore now")
                dispose()
            }
            "resume" -> {
                debugLog("Resuming ARCore now")
                onResume()
            }
            "getTrackingState" -> {
                debugLog("1/3: Requested tracking state, returning that back to Flutter now")

                val trState = arSceneView?.arFrame?.camera?.trackingState
                debugLog("2/3: Tracking state is " + trState.toString())
                methodChannel.invokeMethod("getTrackingState", trState.toString())
            }
            "togglePlaneRenderer" -> {
                debugLog(" Toggle planeRenderer visibility" )
                arSceneView!!.planeRenderer.isVisible = !arSceneView!!.planeRenderer.isVisible
            }
            else -> {
            }
        }
    }

/*    fun maybeEnableArButton() {
        Log.i(TAG,"maybeEnableArButton" )
        try{
            val availability = ArCoreApk.getInstance().checkAvailability(activity.applicationContext)
            if (availability.isTransient) {
                // Re-query at 5Hz while compatibility is checked in the background.
                Handler().postDelayed({ maybeEnableArButton() }, 200)
            }
            if (availability.isSupported) {
                debugLog("AR SUPPORTED")
            } else { // Unsupported or unknown.
                debugLog("AR NOT SUPPORTED")
            }
        }catch (ex:Exception){
            Log.i(TAG,"maybeEnableArButton ${ex.localizedMessage}" )
        }

    }*/

    private fun setupLifeCycle(context: Context) {
        activityLifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                debugLog("onActivityCreated")
//                maybeEnableArButton()
            }

            override fun onActivityStarted(activity: Activity) {
                debugLog("onActivityStarted")
            }

            override fun onActivityResumed(activity: Activity) {
                debugLog("onActivityResumed")
                onResume()
            }

            override fun onActivityPaused(activity: Activity) {
                debugLog("onActivityPaused")
                onPause()
            }

            override fun onActivityStopped(activity: Activity) {
                debugLog("onActivityStopped (Just so you know)")
//                onPause()
            }

            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

            override fun onActivityDestroyed(activity: Activity) {
                debugLog("onActivityDestroyed (Just so you know)")
//                onDestroy()
//                dispose()
            }
        }

        activity.application.registerActivityLifecycleCallbacks(this.activityLifecycleCallbacks)
    }

    private fun planeSurfaceKind(plane: Plane): Pair<Int, String> {
        val ord = plane.type.ordinal
        val kind = when (plane.type) {
            Plane.Type.HORIZONTAL_UPWARD_FACING -> "horizontal_up"
            Plane.Type.HORIZONTAL_DOWNWARD_FACING -> "horizontal_down"
            Plane.Type.VERTICAL -> "vertical"
            else -> "unknown"
        }
        return Pair(ord, kind)
    }

    private fun hitToResultMap(hit: HitResult): HashMap<String, Any> {
        val distance = hit.distance
        val translation = hit.hitPose.translation
        val rotation = hit.hitPose.rotationQuaternion
        val t = hit.trackable
        val (ord, kind) = when (t) {
            is Plane -> planeSurfaceKind(t)
            is InstantPlacementPoint -> Pair(-1, "instant")
            else -> Pair(-1, "unknown")
        }
        return FlutterArCoreHitTestResult(distance, translation, rotation, ord, kind).toHashMap()
    }

    private fun onSingleTap(tap: MotionEvent?) {
        debugLog(" onSingleTap")
        val frame = arSceneView?.arFrame
        if (frame != null) {
            if (tap != null && frame.camera.trackingState == TrackingState.TRACKING) {
                val hitList = frame.hitTest(tap)
                val list = ArrayList<HashMap<String, Any>>()
                var selectedHit: HitResult? = null
                for (hit in hitList) {
                    val trackable = hit.trackable
                    if (trackable is Plane && trackable.isPoseInPolygon(hit.hitPose)) {
                        hit.hitPose
                        list.add(hitToResultMap(hit))
                        if (selectedHit == null) {
                            selectedHit = hit
                        }
                    }
                }
                // Fallback: weak / newly formed planes may fail isPoseInPolygon even on valid taps.
                if (list.isEmpty()) {
                    for (hit in hitList) {
                        val trackable = hit.trackable
                        if (trackable is Plane &&
                                trackable.trackingState == TrackingState.TRACKING &&
                                trackable.subsumedBy == null) {
                            list.add(hitToResultMap(hit))
                            selectedHit = hit
                            break
                        }
                    }
                }
                // Instant placement hits help on low-texture desks before a full plane mesh exists.
                if (list.isEmpty()) {
                    for (hit in hitList) {
                        val trackable = hit.trackable
                        if (trackable is InstantPlacementPoint &&
                                trackable.trackingState == TrackingState.TRACKING) {
                            list.add(hitToResultMap(hit))
                            selectedHit = hit
                            break
                        }
                    }
                }

                pendingPlacementAnchor?.detach()
                pendingPlacementAnchor = null
                if (selectedHit != null) {
                    try {
                        pendingPlacementAnchor = selectedHit!!.createAnchor()
                    } catch (e: Exception) {
                        debugLog("createAnchor from hit failed: ${e.message}")
                    }
                }

                methodChannel.invokeMethod("onPlaneTap", list)
            }
        }
    }

    private fun takeScreenshot(call: MethodCall, result: MethodChannel.Result) {
        try {
            // create bitmap screen capture

            // Create a bitmap the size of the scene view.
            val bitmap: Bitmap = Bitmap.createBitmap(arSceneView!!.getWidth(), arSceneView!!.getHeight(),
                    Bitmap.Config.ARGB_8888)

            // Create a handler thread to offload the processing of the image.
            val handlerThread = HandlerThread("PixelCopier")
            handlerThread.start()
            // Make the request to copy.
            // Make the request to copy.
            PixelCopy.request(arSceneView!!, bitmap, { copyResult ->
                if (copyResult === PixelCopy.SUCCESS) {
                    try {
                        saveBitmapToDisk(bitmap)
                    } catch (e: IOException) {
                        e.printStackTrace();
                    }
                }
                handlerThread.quitSafely()
            }, Handler(handlerThread.getLooper()))

        } catch (e: Throwable) {
            // Several error may come out with file handling or DOM
            e.printStackTrace()
        }
        result.success(null)
    }

    @Throws(IOException::class)
    fun saveBitmapToDisk(bitmap: Bitmap):String {

//        val now = LocalDateTime.now()
//        now.format(DateTimeFormatter.ofPattern("M/d/y H:m:ss"))
        val now = "rawScreenshot"
        // android/data/com.hswo.mvc_2021.hswo_mvc_2021_flutter_ar/files/
        // activity.applicationContext.getFilesDir().toString() //doesnt work!!
        // Environment.getExternalStorageDirectory()
        val mPath: String =  Environment.getExternalStorageDirectory().toString() + "/DCIM/" + now + ".jpg"
        val mediaFile = File(mPath)
        debugLog(mediaFile.toString())
        //Log.i("path","fileoutputstream opened")
        //Log.i("path",mPath)
        val fileOutputStream = FileOutputStream(mediaFile)
        bitmap.compress(Bitmap.CompressFormat.JPEG, 100, fileOutputStream)
        fileOutputStream.flush()
        fileOutputStream.close()
//        Log.i("path","fileoutputstream closed")
        return mPath as String
    }

    private fun arScenViewInit(call: MethodCall, result: MethodChannel.Result, context: Context) {
        debugLog("arScenViewInit")
        val enableTapRecognizer: Boolean? = call.argument("enableTapRecognizer")
        if (enableTapRecognizer != null && enableTapRecognizer) {
            arSceneView
                    ?.scene
                    ?.setOnTouchListener { hitTestResult: HitTestResult, event: MotionEvent ->

                        if (hitTestResult.node != null) {
                            debugLog(" onNodeTap " + hitTestResult.node?.name)
                            debugLog(hitTestResult.node?.localPosition.toString())
                            debugLog(hitTestResult.node?.worldPosition.toString())
                            methodChannel.invokeMethod("onNodeTap", hitTestResult.node?.name)
                            return@setOnTouchListener true
                        }
                        return@setOnTouchListener gestureDetector.onTouchEvent(event)
                    }
        }
        val enableUpdateListener: Boolean? = call.argument("enableUpdateListener")
        if (enableUpdateListener != null && enableUpdateListener) {
            // Set an update listener on the Scene that will hide the loading message once a Plane is
            // detected.
            arSceneView?.scene?.addOnUpdateListener(sceneUpdateListener)
        }

        val enablePlaneRenderer: Boolean? = call.argument("enablePlaneRenderer")
        if (enablePlaneRenderer != null && !enablePlaneRenderer) {
            debugLog(" The plane renderer (enablePlaneRenderer) is set to " + enablePlaneRenderer.toString())
            arSceneView!!.planeRenderer.isVisible = false
        }

        val planeColorStr: String? = call.argument("planeColor")
        if (planeColorStr != null) {
            planeColor = com.google.ar.sceneform.rendering.Color(android.graphics.Color.parseColor("#$planeColorStr"))
        }

        planeColor?.let {
            arSceneView?.planeRenderer?.material?.thenAccept { material ->
                material.setFloat3("color", it)
            }
        }

        result.success(null)
    }

    fun addNodeWithAnchor(flutterArCoreNode: FlutterArCoreNode, result: MethodChannel.Result) {

        if (arSceneView == null) {
            return
        }

        RenderableCustomFactory.makeRenderable(activity.applicationContext, flutterArCoreNode) { renderable, t ->
            if (t != null) {
                result.error("Make Renderable Error", t.localizedMessage, null)
                return@makeRenderable
            }
            val session = arSceneView?.session
            val fromHit = pendingPlacementAnchor
            pendingPlacementAnchor = null
            val myAnchor: Anchor? = when {
                fromHit != null && fromHit.trackingState == TrackingState.TRACKING -> fromHit
                session != null -> {
                    try {
                        session.createAnchor(Pose(flutterArCoreNode.getPosition(), flutterArCoreNode.getRotation()))
                    } catch (e: Exception) {
                        debugLog("fallback createAnchor: ${e.message}")
                        null
                    }
                }
                else -> null
            }
            if (fromHit != null && myAnchor !== fromHit) {
                try {
                    fromHit.detach()
                } catch (_: Exception) {
                }
            }
            if (myAnchor != null) {
                val anchorNode = AnchorNode(myAnchor)
                anchorNode.name = flutterArCoreNode.name
                if (renderable is ModelRenderable) {
                    renderable.isShadowCaster = false
                    renderable.isShadowReceiver = false
                }
                anchorNode.renderable = renderable
                anchorNode.localScale = flutterArCoreNode.scale
                anchorNode.localRotation = flutterArCoreNode.rotation

                debugLog("addNodeWithAnchor inserted ${anchorNode.name}")
                attachNodeToParent(anchorNode, flutterArCoreNode.parentNodeName)

                for (node in flutterArCoreNode.children) {
                    node.parentNodeName = flutterArCoreNode.name
                    onAddNode(node, null)
                }
            }
            result.success(null)
        }
    }

    fun onAddNode(flutterArCoreNode: FlutterArCoreNode, result: MethodChannel.Result?) {

        debugLog(flutterArCoreNode.toString())
        NodeFactory.makeNode(activity.applicationContext, flutterArCoreNode, debug) { node, throwable ->

            debugLog("onAddNode inserted ${node?.name}")

/*            if (flutterArCoreNode.parentNodeName != null) {
                debugLog(flutterArCoreNode.parentNodeName);
                val parentNode: Node? = arSceneView?.scene?.findByName(flutterArCoreNode.parentNodeName)
                parentNode?.addChild(node)
            } else {
                debugLog("addNodeToSceneWithGeometry: NOT PARENT_NODE_NAME")
                arSceneView?.scene?.addChild(node)
            }*/
            if (node != null) {
                attachNodeToParent(node, flutterArCoreNode.parentNodeName)
                for (n in flutterArCoreNode.children) {
                    n.parentNodeName = flutterArCoreNode.name
                    onAddNode(n, null)
                }
            }

        }
        result?.success(null)
    }

    fun attachNodeToParent(node: Node?, parentNodeName: String?) {
        if (parentNodeName != null) {
            debugLog(parentNodeName);
            val parentNode: Node? = arSceneView?.scene?.findByName(parentNodeName)
            parentNode?.addChild(node)
        } else {
            debugLog("addNodeToSceneWithGeometry: NOT PARENT_NODE_NAME")
            arSceneView?.scene?.addChild(node)
        }
    }

    fun removeNode(name: String, result: MethodChannel.Result) {
        val node = arSceneView?.scene?.findByName(name)
        if (node != null) {
            arSceneView?.scene?.removeChild(node);
            debugLog("removed ${node.name}")
        }

        result.success(null)
    }

    private fun normalizedSceneformQuaternion(q: Quaternion): Quaternion {
        val len = sqrt(
            (q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w).toDouble()
        ).toFloat()
        if (len < 1e-6f) {
            return Quaternion()
        }
        return Quaternion(q.x / len, q.y / len, q.z / len, q.w / len)
    }

    fun updateNodeTransform(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("nodeName")
        if (name.isNullOrEmpty()) {
            result.success(null)
            return
        }
        val node = arSceneView?.scene?.findByName(name)
        if (node == null) {
            result.success(null)
            return
        }
        val scaleMap = call.argument<Map<String, *>>("scale")
        if (scaleMap != null) {
            fun num(key: String, def: Float) =
                ((scaleMap[key] as? Number)?.toFloat()) ?: def
            node.localScale = Vector3(num("x", 1f), num("y", 1f), num("z", 1f))
        }
        val rotMap = call.argument<Map<String, *>>("rotation")
        if (rotMap != null) {
            fun rn(key: String, def: Float) =
                ((rotMap[key] as? Number)?.toFloat()) ?: def
            val q = Quaternion(rn("x", 0f), rn("y", 0f), rn("z", 0f), rn("w", 1f))
            node.localRotation = normalizedSceneformQuaternion(q)
        }
        result.success(null)
    }

    fun updateRotation(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val node = arSceneView?.scene?.findByName(name) as RotatingNode
        debugLog("rotating node:  $node")
        val degreesPerSecond = call.argument<Double?>("degreesPerSecond")
        debugLog("rotating value:  $degreesPerSecond")
        if (degreesPerSecond != null) {
            debugLog("rotating value:  ${node.degreesPerSecond}")
            node.degreesPerSecond = degreesPerSecond.toFloat()
        }
        result.success(null)
    }

    fun updateMaterials(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val materials = call.argument<ArrayList<HashMap<String, *>>>("materials")!!
        val node = arSceneView?.scene?.findByName(name)
        val oldMaterial = node?.renderable?.material?.makeCopy()
        if (oldMaterial != null) {
            val material = MaterialCustomFactory.updateMaterial(oldMaterial, materials[0])
            node.renderable?.material = material
        }
        result.success(null)
    }

    override fun getView(): View {
        return arSceneView as View
    }

    override fun dispose() {
        if (arSceneView != null) {
            onPause()
            onDestroy()
        }
    }

    fun onResume() {
        debugLog("onResume()")

        if (arSceneView == null) {
            return
        }

        // request camera permission if not already requested
        if (!ArCoreUtils.hasCameraPermission(activity)) {
            ArCoreUtils.requestCameraPermission(activity, RC_PERMISSIONS)
        }

        if (arSceneView?.session == null) {
            debugLog("session is null")
            try {
                val session = ArCoreUtils.createArSession(activity, mUserRequestedInstall, isAugmentedFaces)
                if (session == null) {
                    // Ensures next invocation of requestInstall() will either return
                    // INSTALLED or throw an exception.
                    mUserRequestedInstall = false
                    return
                } else {
                    val config = Config(session)
                    if (isAugmentedFaces) {
                        config.augmentedFaceMode = Config.AugmentedFaceMode.MESH3D
                    }
                    config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                    config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                    config.focusMode = Config.FocusMode.AUTO
                    // Do NOT use ENVIRONMENTAL_HDR: Sceneform 1.17.x calls
                    // LightEstimate.acquireEnvironmentalHdrCubeMap(), which is missing / mismatched
                    // against newer arcore AARs and crashes with NoSuchMethodError on many devices.
                    try {
                        config.lightEstimationMode = Config.LightEstimationMode.AMBIENT_INTENSITY
                    } catch (e: Exception) {
                        debugLog("lightEstimationMode: ${e.message}")
                    }
                    try {
                        config.instantPlacementMode = Config.InstantPlacementMode.LOCAL_Y_UP
                    } catch (e: Exception) {
                        debugLog("instantPlacementMode: ${e.message}")
                    }
                    session.configure(config)
                    arSceneView?.setupSession(session)
                }
            } catch (ex: UnavailableUserDeclinedInstallationException) {
                // Display an appropriate message to the user zand return gracefully.
                Toast.makeText(activity, "TODO: handle exception " + ex.localizedMessage, Toast.LENGTH_LONG)
                        .show();
                return
            } catch (e: UnavailableException) {
                ArCoreUtils.handleSessionException(activity, e)
                return
            }
        }

        try {
            arSceneView?.resume()
        } catch (ex: CameraNotAvailableException) {
            ArCoreUtils.displayError(activity, "Unable to get camera", ex)
            activity.finish()
            return
        }

        if (arSceneView?.session != null) {
            arSceneView?.planeRenderer?.isVisible = !sceneLightweightMode
            debugLog("Searching for surfaces")
        }
    }

    private fun setLightweightSceneMode(enabled: Boolean) {
        sceneLightweightMode = enabled
        if (arSceneView?.session != null) {
            arSceneView?.planeRenderer?.isVisible = !enabled
        }
    }

    fun onPause() {
        if (arSceneView != null) {
            arSceneView?.pause()
        }
    }

    fun onDestroy() {
      if (arSceneView != null) {
            debugLog("Goodbye ARCore! Destroying the Activity now 7.")

            try {
                pendingPlacementAnchor?.detach()
                pendingPlacementAnchor = null
                arSceneView?.scene?.removeOnUpdateListener(sceneUpdateListener)
                arSceneView?.scene?.removeOnUpdateListener(faceSceneUpdateListener)
                debugLog("Goodbye arSceneView.")

                arSceneView?.destroy()
                arSceneView = null

            }catch (e : Exception){
                e.printStackTrace();
           }
        }
    }

    /* private fun tryPlaceNode(tap: MotionEvent?, frame: Frame) {
        if (tap != null && frame.camera.trackingState == TrackingState.TRACKING) {
            for (hit in frame.hitTest(tap)) {
                val trackable = hit.trackable
                if (trackable is Plane && trackable.isPoseInPolygon(hit.hitPose)) {
                    // Create the Anchor.
                    val anchor = hit.createAnchor()
                    val anchorNode = AnchorNode(anchor)
                    anchorNode.setParent(arSceneView?.scene)

                    ModelRenderable.builder()
                            .setSource(activity.applicationContext, Uri.parse("TocoToucan.sfb"))
                            .build()
                            .thenAccept { renderable ->
                                val node = Node()
                                node.renderable = renderable
                                anchorNode.addChild(node)
                            }.exceptionally { throwable ->
                                Log.e(TAG, "Unable to load Renderable.", throwable);
                                return@exceptionally null
                            }
                }
            }
        }

    }*/

    /*    fun updatePosition(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val node = arSceneView?.scene?.findByName(name)
        node?.localPosition = parseVector3(call.arguments as HashMap<String, Any>)
        result.success(null)
    }*/
}
