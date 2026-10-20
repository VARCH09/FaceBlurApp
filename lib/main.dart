
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const FaceBlurApp());
}

class FaceBlurApp extends StatelessWidget {
  const FaceBlurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FaceBlur',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101116),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B7CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  static const MethodChannel _opencvChannel =
      MethodChannel('com.example.face_blur_app/opencv');

  XFile? _selectedMedia;
  bool _isVideo = false;
  bool _isPicking = false;
  bool _isProcessing = false;

  String? _error;
  String? _processedImagePath;
  String? _processedVideoPath;

  VideoPlayerController? _videoController;

  // ------------------------------------------------------------
  // IMAGE PROCESSING
  // ------------------------------------------------------------

  Future<void> _blurFaces() async {
    if (_selectedMedia == null || _isVideo || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final String? outputPath =
          await _opencvChannel.invokeMethod<String>(
        'blurImage',
        {'imagePath': _selectedMedia!.path},
      );

      if (!mounted) return;

      if (outputPath == null || outputPath.isEmpty) {
        throw Exception('No processed image was returned.');
      }

      setState(() {
        _processedImagePath = outputPath;
      });

      _showMessage('Face blurring completed successfully.');
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Face blurring failed: ${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not blur faces: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // VIDEO PROCESSING
  // ------------------------------------------------------------

  Future<void> _blurVideo() async {
    if (_selectedMedia == null || !_isVideo || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final String? outputPath =
          await _opencvChannel.invokeMethod<String>(
        'blurVideo',
        {'videoPath': _selectedMedia!.path},
      );

      if (!mounted) return;

      if (outputPath == null || outputPath.isEmpty) {
        throw Exception('No processed video was returned.');
      }

      final newController =
          VideoPlayerController.file(File(outputPath));

      try {
        await newController.initialize();
      } catch (_) {
        await newController.dispose();
        rethrow;
      }

      if (!mounted) {
        await newController.dispose();
        return;
      }

      final oldController = _videoController;

      setState(() {
        _processedVideoPath = outputPath;
        _videoController = newController;
      });

      await oldController?.dispose();

      if (!mounted) return;

      _showMessage('Video face blurring completed successfully.');
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Video processing failed: ${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not process video: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // MEDIA PICKING
  // ------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source);

      if (file == null) return;

      await _setMedia(file, isVideo: false);
    } catch (e) {
      _showMessage('Could not select image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (file == null) return;

      await _setMedia(file, isVideo: true);
    } catch (e) {
      _showMessage('Could not select video: $e');
    }
  }

  Future<void> _setMedia(
    XFile file, {
    required bool isVideo,
  }) async {
    setState(() {
      _isPicking = true;
      _error = null;
    });

    VideoPlayerController? newController;

    try {
      if (isVideo) {
        newController =
            VideoPlayerController.file(File(file.path));

        await newController.initialize();
      }

      if (!mounted) {
        await newController?.dispose();
        return;
      }

      final oldController = _videoController;

      setState(() {
        _selectedMedia = file;
        _isVideo = isVideo;
        _videoController = newController;
        _isPicking = false;
        _isProcessing = false;
        _processedImagePath = null;
        _processedVideoPath = null;
        _error = null;
      });

      await oldController?.dispose();
    } catch (e) {
      await newController?.dispose();

      if (mounted) {
        setState(() {
          _isPicking = false;
          _error = 'Could not open media: $e';
        });
      }
    }
  }

  Future<void> _clearMedia() async {
    final oldController = _videoController;

    setState(() {
      _selectedMedia = null;
      _videoController = null;
      _isVideo = false;
      _isProcessing = false;
      _error = null;
      _processedImagePath = null;
      _processedVideoPath = null;
    });

    await oldController?.dispose();
  }

  // ------------------------------------------------------------
  // SAVE PROCESSED MEDIA
  // ------------------------------------------------------------

  Future<bool> _requestGalleryAccess() async {
    var hasAccess = await Gal.hasAccess();

    if (!hasAccess) {
      hasAccess = await Gal.requestAccess();
    }

    return hasAccess;
  }

  Future<void> _saveToGallery() async {
    final path = _processedImagePath;

    if (path == null) return;

    try {
      final hasAccess = await _requestGalleryAccess();

      if (!hasAccess) {
        _showMessage('Gallery permission was not granted.');
        return;
      }

      await Gal.putImage(path);

      if (!mounted) return;

      _showMessage('Blurred image saved to your gallery!');
    } on GalException catch (e) {
      _showMessage('Could not save image: ${e.type.message}');
    } catch (e) {
      _showMessage('Could not save image: $e');
    }
  }

  Future<void> _saveVideoToGallery() async {
    final path = _processedVideoPath;

    if (path == null) return;

    try {
      final hasAccess = await _requestGalleryAccess();

      if (!hasAccess) {
        _showMessage('Gallery permission was not granted.');
        return;
      }

      await Gal.putVideo(path);

      if (!mounted) return;

      _showMessage('Blurred video saved to your gallery!');
    } on GalException catch (e) {
      _showMessage('Could not save video: ${e.type.message}');
    } catch (e) {
      _showMessage('Could not save video: $e');
    }
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1C1D25),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF302B50),
          child: Icon(
            icon,
            color: const Color(0xFFB8ACFF),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: (_isPicking || _isProcessing) ? null : onTap,
      ),
    );
  }

  // ------------------------------------------------------------
  // MEDIA PREVIEW
  // ------------------------------------------------------------

  Widget _mediaPreview() {
    if (_selectedMedia == null) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1D25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.face_retouching_natural,
              size: 58,
              color: Color(0xFF9D8EFF),
            ),
            SizedBox(height: 12),
            Text(
              'Your preview appears here',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 6),
            Text(
              'Choose a photo or video to begin',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    if (_isVideo) {
      final controller = _videoController;

      if (controller == null ||
          !controller.value.isInitialized) {
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio > 0
              ? controller.value.aspectRatio
              : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              IconButton.filled(
                iconSize: 38,
                onPressed: () {
                  setState(() {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  });
                },
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final imagePath =
        _processedImagePath ?? _selectedMedia!.path;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.file(
        File(imagePath),
        key: ValueKey(imagePath),
        width: double.infinity,
        height: 320,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox(
            height: 220,
            child: Center(
              child: Text('Could not display this image.'),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // PROCESSING BUTTONS
  // ------------------------------------------------------------

  Widget _buildProcessButton() {
    final isBusy = _isProcessing;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isVideo || isBusy ? null : _blurFaces,
        icon: isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : Icon(
                _isVideo
                    ? Icons.video_settings
                    : Icons.face_retouching_natural,
              ),
        label: Text(
  isBusy ? 'Blurring faces...' : 'Blur Faces',
),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF8B7CFF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSaveButton({
    required bool isVideo,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isVideo
            ? _saveVideoToGallery
            : _saveToGallery,
        icon: const Icon(Icons.save_alt),
        label: Text(
          isVideo ? 'Save Video to Gallery' : 'Save to Gallery',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB8ACFF),
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(
            color: Color(0xFF8B7CFF),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // MAIN UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final hasProcessedMedia = _isVideo
        ? _processedVideoPath != null
        : _processedImagePath != null;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.blur_on,
              color: Color(0xFFB8ACFF),
              size: 29,
            ),
            SizedBox(width: 10),
            Text(
              'FaceBlur',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF101116),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Protect your privacy.',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Blur faces in photos and videos directly on your device.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'SELECT MEDIA',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _actionButton(
              icon: Icons.image_outlined,
              title: 'Choose an image',
              subtitle: 'JPG, PNG and other supported images',
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            _actionButton(
              icon: Icons.video_library_outlined,
              title: 'Choose a video',
              subtitle: 'Select a video from your gallery',
              onTap: _pickVideo,
            ),
            _actionButton(
              icon: Icons.camera_alt_outlined,
              title: 'Take a photo',
              subtitle: 'Capture an image with your camera',
              onTap: () => _pickImage(ImageSource.camera),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PREVIEW',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedMedia != null)
                  TextButton(
                    onPressed:
                        (_isProcessing || _isPicking)
                            ? null
                            : _clearMedia,
                    child: const Text('Remove'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            if (_isPicking)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              _mediaPreview(),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ],

            if (_selectedMedia != null) ...[
              const SizedBox(height: 12),
              Text(
                _selectedMedia!.name,
                style: const TextStyle(color: Colors.white60),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              if (!_isVideo) _buildProcessButton(),

              if (hasProcessedMedia) ...[
                const SizedBox(height: 10),
                _buildSaveButton(isVideo: _isVideo),
              ],

              if (_isVideo && _processedVideoPath == null) ...[
                const SizedBox(height: 10),
                const Text(
                  'Processing may take some time depending on video length.',
                  style: TextStyle(
                    color: Color(0xFFB8ACFF),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
