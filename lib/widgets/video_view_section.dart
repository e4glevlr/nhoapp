import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoViewSection extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final String status;
  final bool isLoading;
  final bool isListening;
  final String? errorMessage;

  const VideoViewSection({
    Key? key,
    required this.renderer,
    required this.status,
    required this.isLoading,
    required this.isListening,
    this.errorMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueGrey, width: 2.0),
            borderRadius: BorderRadius.circular(12.0),
            color: Colors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video View
                if (renderer.textureId != null)
                  RTCVideoView(
                    renderer,
                    mirror: false,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  )
                else
                  const Center(
                    child: Text(
                      "Stream not started",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),

                // Loading Indicator
                if (isLoading && status.contains('Connecting'))
                  const CircularProgressIndicator(),

                // Status Overlay
                if (!isLoading && status != 'Connected' && status != 'Completed')
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Status: $status${errorMessage != null ? '\nError: $errorMessage' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                // Listening Indicator
                if (isListening)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}