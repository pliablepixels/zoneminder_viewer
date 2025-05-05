import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../widgets/mjpeg_view.dart';

class EventPlaybackScreen extends StatelessWidget {
  final int eventId;
  final String monitorName;
  final String? cause;
  final String? notes;
  final String playbackUrl;
  
  static final Logger _logger = Logger('EventPlaybackScreen');

  EventPlaybackScreen({
    super.key,
    required this.eventId,
    required this.monitorName,
    required this.playbackUrl,
    this.cause,
    this.notes,
  }) {
    _logger.info('Opening event playback for event $eventId');
    _logger.info('Playback URL: $playbackUrl');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Event $eventId'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event details section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitor: $monitorName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (cause != null && cause!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('Cause: $cause'),
                  ),
                if (notes != null && notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('Notes: $notes'),
                  ),
                const Divider(height: 20),
                SelectableText(
                  'Stream URL:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SelectableText(
                  playbackUrl,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          
          // Video player section
          Expanded(
            child: MjpegView(
              streamUrl: Future.value(playbackUrl),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
