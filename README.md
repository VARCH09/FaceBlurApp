# FaceBlur

**Protect your privacy. Blur faces. Keep your images private.**

FaceBlur is an Android application built with Flutter, Kotlin, and OpenCV that detects faces in images and applies Gaussian blur to help protect personal privacy. It uses the lightweight YuNet face detection model and integrates native Android image processing with a Flutter user interface.

<p align="center">
  <img src="screenshots/home-screen.png" alt="FaceBlur application home screen" width="300">
</p>

<p align="center">
  <b>Flutter</b> · <b>Kotlin</b> · <b>OpenCV</b> · <b>YuNet</b>
</p>

## Features

- **Face detection:** Detect faces in images using the YuNet deep-learning model.
- **Automatic face blurring:** Apply Gaussian blur to detected face regions.
- **Gallery integration:** Select images from your device.
- **Camera capture:** Take photos directly from the application.
- **Image preview:** Preview selected media before processing.
- **Save processed images:** Export the resulting image to your device's gallery.
- **Native Android processing:** Run face detection and image processing through Kotlin and OpenCV.
- **Privacy-focused design:** Process images locally on the device without requiring a cloud-based face detection service.

> **Current scope:** Image face detection and blurring are implemented. Video selection and preview are available, but video face-blurring and video export are not currently supported.

## Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | User interface and application state |
| Dart | Frontend logic and media selection |
| Kotlin | Native Android implementation |
| OpenCV | Image processing and face detection integration |
| YuNet | Neural-network-based face detection |
| ONNX | Format of the pretrained YuNet model |
| MethodChannel | Communication between Flutter and Kotlin |
| `image_picker` | Image selection and camera capture |
| `gal` | Saving processed images to the gallery |

## How It Works

1. **Select an image:** Choose an existing photo from the gallery or capture a new one.
2. **Load the image:** The Flutter application passes the image path to native Android code through a MethodChannel.
3. **Detect faces:** OpenCV loads the YuNet model and identifies faces in the image.
4. **Extract face regions:** The application uses the detected bounding boxes to locate each face.
5. **Apply Gaussian blur:** OpenCV blurs the detected face regions while preserving the rest of the image.
6. **Save the result:** The processed image is returned to Flutter for preview and can be saved to the device gallery.

## Architecture

```text
              Flutter UI (Dart)
                     |
          Image selection / Camera
                     |
                MethodChannel
                     |
              Native Android
                 (Kotlin)
                     |
              OpenCV + YuNet
                     |
              Face Detection
                     |
             Face Region Cropping
                     |
               Gaussian Blur
                     |
              Processed Image
                     |
             Flutter Preview
                     |
               Save to Gallery
```

## Getting Started

### Prerequisites

Install the following tools before running the project:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Android Studio](https://developer.android.com/studio)
- Android SDK and platform tools
- Git
- A physical Android device or Android emulator

### Installation

**1. Clone the repository**

```bash
git clone https://github.com/VARCH09/FaceBlurApp.git
cd FaceBlurApp
```

**2. Install Flutter dependencies**

```bash
flutter pub get
```

**3. Verify your environment**

```bash
flutter doctor
```

Resolve any required Android toolchain issues reported by Flutter.

**4. Connect an Android device or start an emulator**

For a physical device, enable USB debugging and authorize your computer.

**5. Run the application**

```bash
flutter run
```

### Build a Release APK

To generate a release APK:

```bash
flutter build apk --release
```

The APK will be generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Install it on a connected device using:

```bash
flutter install
```

## Project Structure

```text
FaceBlurApp/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── assets/
│               │   └── face_detection_yunet_2023mar.onnx
│               ├── kotlin/
│               │   └── .../
│               │       └── MainActivity.kt
│               └── AndroidManifest.xml
├── lib/
│   └── main.dart
├── screenshots/
│   └── home-screen.png
├── test/
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
└── README.md
```

*The structure above is representative; actual package names and optional files may differ.*

## Privacy and Limitations

- Image processing is performed locally using the application's native Android implementation.
- The app does not require a cloud-based face detection API for its image-processing pipeline.
- Detection accuracy can vary with image quality, lighting, face size, orientation, and occlusion.
- Gaussian blur is a visual anonymization technique and should not be considered a guarantee of irreversible identity protection.
- Video processing is not yet implemented.

## Future Improvements

- Add reliable frame-by-frame video face detection and blurring.
- Support real-time face blurring using the camera.
- Add adjustable blur intensity and alternative anonymization effects.
- Improve face detection for small, rotated, or partially obscured faces.
- Add automated tests and performance benchmarks.
- Explore optimized inference for resource-constrained Android devices.

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [OpenCV](https://opencv.org/)
- [OpenCV Zoo — YuNet face detection model](https://github.com/opencv/opencv_zoo)
- [ONNX](https://onnx.ai/)

Review the applicable licenses and attribution requirements for third-party libraries and model files before distributing the application.

## License

This project does not yet specify a license. Add a `LICENSE` file if you intend to grant others permission to use, modify, and distribute the code. Without an explicit license, others generally do not automatically receive those permissions.

---

**Built with Flutter, Kotlin, and OpenCV.**
