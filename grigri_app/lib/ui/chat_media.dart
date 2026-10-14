import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/api.dart';
import '../data/grigri_store.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';

/// Where a chat's photo or video comes from.
enum ChatMediaSource { takePhoto, choosePhoto, recordVideo, chooseVideo }

/// Picks a photo or video for a chat message; null when cancelled.
typedef ChatMediaPicker = Future<ChatMedia?> Function(ChatMediaSource source);

/// The longest side of a chat photo, in pixels.
const chatPhotoSide = 1600.0;

/// The device's picker: only photos and videos are offered. Photos are
/// downsized and recompressed as they're picked (as profile photos are);
/// the camera stops recording at [maxVideoDuration] where the device lets
/// the app say (the gallery's videos are checked for size instead).
Future<ChatMedia?> pickChatMedia(ChatMediaSource source) async {
  final picker = ImagePicker();
  final XFile? file = switch (source) {
    ChatMediaSource.takePhoto ||
    ChatMediaSource.choosePhoto => await picker.pickImage(
      source: source == ChatMediaSource.takePhoto
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: chatPhotoSide,
      maxHeight: chatPhotoSide,
      imageQuality: 75,
    ),
    ChatMediaSource.recordVideo ||
    ChatMediaSource.chooseVideo => await picker.pickVideo(
      source: source == ChatMediaSource.recordVideo
          ? ImageSource.camera
          : ImageSource.gallery,
      maxDuration: maxVideoDuration,
    ),
  };
  if (file == null) return null;
  final kind =
      source == ChatMediaSource.recordVideo ||
          source == ChatMediaSource.chooseVideo
      ? MediaKind.video
      : MediaKind.image;
  return ChatMedia(await file.readAsBytes(), kind);
}

/// Asks where the photo or video comes from: the camera (where there is
/// one) or the gallery. Null when dismissed.
Future<ChatMediaSource?> chooseChatMediaSource(BuildContext context) {
  final camera = ImagePicker().supportsImageSource(ImageSource.camera);
  final l = context.l10n;
  Widget option(IconData icon, String label, ChatMediaSource source) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.pop(context, source),
      );
  return showModalBottomSheet<ChatMediaSource>(
    context: context,
    backgroundColor: Mountain.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (camera)
            option(
              Icons.photo_camera_outlined,
              l.takePhoto,
              ChatMediaSource.takePhoto,
            ),
          option(
            Icons.photo_library_outlined,
            l.choosePhoto,
            ChatMediaSource.choosePhoto,
          ),
          if (camera)
            option(
              Icons.videocam_outlined,
              l.recordVideo,
              ChatMediaSource.recordVideo,
            ),
          option(
            Icons.video_library_outlined,
            l.chooseVideo,
            ChatMediaSource.chooseVideo,
          ),
        ],
      ),
    ),
  );
}

/// A message's photo or video in its bubble: the photo itself (tap to see
/// it whole), or a poster with a play button (tap to play). Videos load
/// only when played, so an open chat downloads none of them.
class ChatAttachment extends StatelessWidget {
  const ChatAttachment(this.attachment, {super.key});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    final radius = BorderRadius.circular(12);
    final url = store.api.photoUrl(attachment.key);
    if (attachment.kind == MediaKind.video) {
      return Semantics(
        button: true,
        label: l.playVideo,
        child: InkWell(
          key: ValueKey('video ${attachment.key}'),
          borderRadius: radius,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => VideoViewer(url: url)),
          ),
          child: Container(
            width: 220,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: radius,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.play_circle_fill,
                  size: 52,
                  color: Mountain.snow,
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam,
                        size: 16,
                        color: Mountain.snow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l.videoMessage,
                        style: const TextStyle(color: Mountain.snow),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final image = store.photo(attachment.key);
    return InkWell(
      key: ValueKey('photo ${attachment.key}'),
      borderRadius: radius,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PhotoViewer(image: image)),
      ),
      // A fixed frame, cropped to fill it, so the chat doesn't jump as
      // photos load; tapping shows it whole.
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: 240,
          height: 180,
          child: Image(
            image: image,
            fit: BoxFit.cover,
            semanticLabel: l.photoMessage,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, _, _) => Center(
              child: Text(
                l.mediaUnavailable,
                style: const TextStyle(color: Mountain.granite),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chat photo, whole, to pinch and zoom.
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black),
    body: InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: Image(image: image, fit: BoxFit.contain),
      ),
    ),
  );
}

/// A chat video, played from where the site serves it.
class VideoViewer extends StatefulWidget {
  const VideoViewer({super.key, required this.url});

  final Uri url;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late final VideoPlayerController _video = VideoPlayerController.networkUrl(
    widget.url,
  );
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _video.addListener(_changed);
    _video.initialize().then(
      (_) {
        if (mounted) _video.play();
      },
      onError: (Object _) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  void _changed() {
    if (!mounted) return;
    if (_video.value.hasError) _failed = true;
    setState(() {});
  }

  @override
  void dispose() {
    _video.removeListener(_changed);
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _video.value;
    final Widget body;
    if (_failed) {
      body = Center(
        child: Text(
          context.l10n.videoUnavailable,
          style: const TextStyle(color: Mountain.snow),
        ),
      );
    } else if (!value.isInitialized) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = GestureDetector(
        onTap: () => value.isPlaying ? _video.pause() : _video.play(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(_video),
              ),
            ),
            if (!value.isPlaying)
              const Icon(
                Icons.play_circle_fill,
                size: 72,
                color: Mountain.snow,
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: VideoProgressIndicator(
                  _video,
                  allowScrubbing: true,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: body,
    );
  }
}
