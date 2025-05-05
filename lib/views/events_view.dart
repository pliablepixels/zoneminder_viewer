import 'package:flutter/material.dart';

class EventsView extends StatelessWidget {
  const EventsView({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual event data
    final mockEvents = List.generate(10, (index) => {
      'camera': 'Camera ${index % 4 + 1}',
      'timestamp': DateTime.now().subtract(Duration(hours: index)),
      'event': 'Motion detected',
    });

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: mockEvents.length,
      itemBuilder: (context, index) {
        final event = mockEvents[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.event),
            title: Text(
              event['event'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Camera: ${event['camera']}'),
                Text(
                  'Time: ${_formatDateTime(event['timestamp'] as DateTime)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to event details
            },
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
