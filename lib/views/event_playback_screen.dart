import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../widgets/mjpeg_view.dart';

class EventPlaybackScreen extends StatelessWidget {
  final int eventId;
  final String monitorName;
  final String? cause;
  final String? notes;
  final Future<String> playbackUrl;
  
  static final Logger _logger = Logger('EventPlaybackScreen');

  EventPlaybackScreen({
    super.key,
    required this.eventId,
    required this.monitorName,
    required Future<String> playbackUrl,
    this.cause,
    this.notes,
  }) : playbackUrl = playbackUrl.then((url) {
      _logger.info('Opening event playback for event $eventId');
      _logger.info('Playback URL: $url');
      return url;
    });

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
                const Text(
                  'Stream URL:',
                  style: TextStyle(fontSize: 12),
                ),
                FutureBuilder<String>(
                  future: playbackUrl,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Loading URL...', style: TextStyle(fontStyle: FontStyle.italic));
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                    }
                    return SelectableText(
                      snapshot.data ?? 'No URL available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Video player section
          Expanded(
            child: FutureBuilder<String>(
              future: playbackUrl,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No stream URL available'));
                }
                return MjpegView(
                  streamUrl: Future.value(snapshot.data!),
                  fit: BoxFit.contain,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
