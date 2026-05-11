package com.muzammil.arcore.flutter.plus.flutter_models

class FlutterArCoreHitTestResult(
    val distance: Float,
    val translation: FloatArray,
    val rotation: FloatArray,
    /** [Plane.Type.ordinal], or `-1` for instant / unknown. */
    val planeTypeOrdinal: Int = -1,
    /** `horizontal_up`, `horizontal_down`, `vertical`, `instant`, `unknown` */
    val surfaceKind: String = "unknown",
) {

    fun toHashMap(): HashMap<String, Any> {
        val map: HashMap<String, Any> = HashMap<String, Any>()
        map["distance"] = distance.toDouble()
        map["pose"] = FlutterArCorePose(translation, rotation).toHashMap()
        map["planeTypeOrdinal"] = planeTypeOrdinal
        map["surfaceKind"] = surfaceKind
        return map
    }
}
