
package com.example.face_blur_app

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.core.Mat
import org.opencv.core.Rect
import org.opencv.core.Size
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import org.opencv.objdetect.FaceDetectorYN
import org.opencv.videoio.VideoCapture
import org.opencv.videoio.VideoWriter
import org.opencv.videoio.Videoio
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "FaceBlur"
        private const val CHANNEL = "com.example.face_blur_app/opencv"
        private const val MODEL_NAME = "face_detection_yunet_2023mar.onnx"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "initializeOpenCV" -> {
                    try {
                        result.success(OpenCVLoader.initLocal())
                    } catch (e: Exception) {
                        Log.e(TAG, "OpenCV initialization failed", e)
                        result.error("OPENCV_INIT_ERROR", e.message, null)
                    }
                }

                "blurImage", "blurVideo" -> {
                    val path = call.argument<String>("imagePath")
                        ?: call.argument<String>("videoPath")

                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "A media path is required.", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            check(OpenCVLoader.initLocal()) {
                                "OpenCV could not be initialized."
                            }

                            val output = if (call.method == "blurImage") {
                                blurImage(path)
                            } else {
                                blurVideo(path)
                            }

                            runOnUiThread { result.success(output) }
                        } catch (e: Exception) {
                            Log.e(TAG, "${call.method} failed", e)
                            runOnUiThread {
                                result.error(
                                    "PROCESSING_FAILED",
                                    e.message ?: "Media processing failed.",
                                    null
                                )
                            }
                        }
                    }.start()
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun getModelFile(): File {
        val model = File(filesDir, MODEL_NAME)

        if (!model.exists() || model.length() == 0L) {
            assets.open(MODEL_NAME).use { input ->
                FileOutputStream(model).use { output -> input.copyTo(output) }
            }
        }

        check(model.exists() && model.length() > 0L) {
            "YuNet model is missing or empty."
        }

        return model
    }

    private fun createDetector(model: File, image: Mat): FaceDetectorYN {
        return FaceDetectorYN.create(
            model.absolutePath,
            "",
            Size(image.cols().toDouble(), image.rows().toDouble()),
            0.5f,
            0.3f,
            5000
        )
    }

    private fun blurDetectedFaces(image: Mat, detector: FaceDetectorYN): Int {
        detector.setInputSize(Size(image.cols().toDouble(), image.rows().toDouble()))

        val faces = Mat()

        try {
            detector.detect(image, faces)

            var blurred = 0

            for (i in 0 until faces.rows()) {
                val data = FloatArray(faces.cols())
                val read = faces.get(i, 0, data)

                if (faces.cols() < 4 || read <= 0) continue

                val x = data[0].toInt()
                val y = data[1].toInt()
                val w = data[2].toInt()
                val h = data[3].toInt()

                if (w <= 0 || h <= 0) continue

                val px = (w * 0.20).toInt()
                val py = (h * 0.20).toInt()

                val left = (x - px).coerceIn(0, image.cols())
                val top = (y - py).coerceIn(0, image.rows())
                val right = (x + w + px).coerceIn(0, image.cols())
                val bottom = (y + h + py).coerceIn(0, image.rows())

                if (right <= left || bottom <= top) continue

                val roi = image.submat(
                    Rect(left, top, right - left, bottom - top)
                )

                try {
                    Imgproc.GaussianBlur(
                        roi, roi, Size(0.0, 0.0), 25.0, 25.0
                    )
                    blurred++
                } finally {
                    roi.release()
                }
            }

            return blurred
        } finally {
            faces.release()
        }
    }

    private fun blurImage(path: String): String {
        val input = File(path)
        require(input.exists()) { "Selected image does not exist." }

        val image = Imgcodecs.imread(input.absolutePath)
        require(!image.empty()) { "OpenCV could not read this image." }

        try {
            val detector = createDetector(getModelFile(), image)
            val count = blurDetectedFaces(image, detector)

            Log.d(TAG, "Image processed; faces blurred: $count")

            val output = File(cacheDir, "blurred_${System.currentTimeMillis()}.jpg")
            check(Imgcodecs.imwrite(output.absolutePath, image)) {
                "Could not save processed image."
            }

            return output.absolutePath
        } finally {
            image.release()
        }
    }

    private fun blurVideo(path: String): String {
        val input = File(path)
        require(input.exists()) { "Selected video does not exist." }

        val capture = VideoCapture()
        var writer: VideoWriter? = null
        var frame: Mat? = null

        try {
            check(capture.open(input.absolutePath)) {
                "OpenCV could not decode this video. Its codec may not be supported by this Android build."
            }

            val width = capture.get(Videoio.CAP_PROP_FRAME_WIDTH).toInt()
            val height = capture.get(Videoio.CAP_PROP_FRAME_HEIGHT).toInt()
            val reportedFps = capture.get(Videoio.CAP_PROP_FPS)
            val fps = if (reportedFps.isFinite() && reportedFps in 1.0..120.0) {
                reportedFps
            } else {
                30.0
            }

            require(width > 0 && height > 0) {
                "Video dimensions could not be read."
            }

            Log.d(TAG, "Video input: ${width}x$height at $fps FPS")

            val output = File(
                cacheDir,
                "blurred_${System.currentTimeMillis()}.mp4"
            )

            writer = VideoWriter(
                output.absolutePath,
                VideoWriter.fourcc('m', 'p', '4', 'v'),
                fps,
                Size(width.toDouble(), height.toDouble()),
                true
            )

            check(writer.isOpened) {
                "OpenCV could not encode MP4 on this device. The Android OpenCV build may lack a compatible video encoder."
            }

            val detector = FaceDetectorYN.create(
                getModelFile().absolutePath,
                "",
                Size(width.toDouble(), height.toDouble()),
                0.5f,
                0.3f,
                5000
            )

            frame = Mat()
            var frameCount = 0
            var facesBlurred = 0

            while (capture.read(frame) && !frame.empty()) {
                facesBlurred += blurDetectedFaces(frame, detector)
                writer.write(frame)
                frameCount++

                if (frameCount % 100 == 0) {
                    Log.d(TAG, "Processed $frameCount video frames")
                }
            }

            check(frameCount > 0) {
                "No video frames were decoded."
            }

            writer.release()
            writer = null
            capture.release()

            check(output.exists() && output.length() > 0L) {
                "Processed video was not created."
            }

            Log.d(
                TAG,
                "Video output: ${output.absolutePath}; " +
                    "frames=$frameCount; face regions blurred=$facesBlurred; " +
                    "bytes=${output.length()}"
            )

            return output.absolutePath
        } finally {
            frame?.release()
            writer?.release()
            capture.release()
        }
    }
}
