package com.example.safesite_ai

import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.safesite.ai/video_frames"
    private val executor = Executors.newSingleThreadExecutor()
    private var cachedRetriever: MediaMetadataRetriever? = null
    private var cachedPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFrameAtTime" -> {
                    val path = call.argument<String>("videoPath")
                    val timeMs = call.argument<Number>("timeMs")?.toLong() ?: 0L
                    val maxDimension = call.argument<Int>("maxDimension") ?: 640

                    if (path == null) {
                        result.error("INVALID_ARGUMENTS", "videoPath cannot be null", null)
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        try {
                            if (cachedPath != path || cachedRetriever == null) {
                                try {
                                    cachedRetriever?.release()
                                } catch (e: Exception) {}
                                val retriever = MediaMetadataRetriever()
                                retriever.setDataSource(path)
                                cachedRetriever = retriever
                                cachedPath = path
                            }

                            val timeUs = timeMs * 1000L
                            val rawBitmap = cachedRetriever?.getFrameAtTime(
                                timeUs,
                                MediaMetadataRetriever.OPTION_CLOSEST
                            ) ?: cachedRetriever?.getFrameAtTime(timeUs)

                            if (rawBitmap != null) {
                                val rotationStr = cachedRetriever?.extractMetadata(
                                    MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION
                                )
                                val rotation = rotationStr?.toIntOrNull() ?: 0

                                val orientedBitmap = if ((rotation == 90 || rotation == 270) && rawBitmap.width > rawBitmap.height) {
                                    val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
                                    Bitmap.createBitmap(rawBitmap, 0, 0, rawBitmap.width, rawBitmap.height, matrix, true)
                                } else if (rotation == 180) {
                                    val matrix = Matrix().apply { postRotate(180f) }
                                    Bitmap.createBitmap(rawBitmap, 0, 0, rawBitmap.width, rawBitmap.height, matrix, true)
                                } else {
                                    rawBitmap
                                }

                                val w = orientedBitmap.width
                                val h = orientedBitmap.height
                                val scaledBitmap = if (w > maxDimension || h > maxDimension) {
                                    val ratio = if (w > h) maxDimension.toFloat() / w else maxDimension.toFloat() / h
                                    val targetW = (w * ratio).toInt().coerceAtLeast(1)
                                    val targetH = (h * ratio).toInt().coerceAtLeast(1)
                                    Bitmap.createScaledBitmap(orientedBitmap, targetW, targetH, true)
                                } else {
                                    orientedBitmap
                                }

                                val stream = ByteArrayOutputStream()
                                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)
                                val byteArray = stream.toByteArray()

                                if (orientedBitmap != rawBitmap) {
                                    rawBitmap.recycle()
                                }
                                if (scaledBitmap != orientedBitmap) {
                                    orientedBitmap.recycle()
                                }
                                scaledBitmap.recycle()

                                runOnUiThread {
                                    result.success(byteArray)
                                }
                            } else {
                                runOnUiThread {
                                    result.success(null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("FRAME_EXTRACTION_ERROR", e.localizedMessage, null)
                            }
                        }
                    }
                }
                "releaseRetriever" -> {
                    executor.execute {
                        try {
                            cachedRetriever?.release()
                            cachedRetriever = null
                            cachedPath = null
                        } catch (e: Exception) {}
                        runOnUiThread {
                            result.success(true)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        executor.execute {
            try {
                cachedRetriever?.release()
                cachedRetriever = null
            } catch (e: Exception) {}
        }
        executor.shutdown()
    }
}
