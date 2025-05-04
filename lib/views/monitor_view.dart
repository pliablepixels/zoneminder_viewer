import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../services/zoneminder_service.dart';
import '../widgets/mjpeg_view.dart';

class MonitorView extends StatefulWidget {
  const MonitorView({super.key});

  @override
  State<MonitorView> createState() => _MonitorViewState();
}

class _MonitorViewState extends State<MonitorView> {
  final ZoneMinderService _zoneminderService = ZoneMinderService();
  List<Map<String, dynamic>> _monitors = [];
  bool _isLoading = true;
  String? _error;



  @override
  void initState() {
    super.initState();
    _fetchMonitors();
  }

  Future<void> _fetchMonitors() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final monitors = await _zoneminderService.getMonitors();
      setState(() {
        _monitors = monitors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch monitors: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Monitor'),
        backgroundColor: Colors.grey[900],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 16/9,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: _monitors.length,
                  itemBuilder: (context, index) {
                    final monitor = _monitors[index]['Monitor'];
                    // debugPrint('Monitor data: $monitor');
                    final monitorId = monitor['Id'] as int?;
                    if (monitorId == null) {
                      return Card(
                        elevation: 4,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: Colors.grey[300],
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Invalid Monitor',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'ID: ${monitor['Id']}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Name: ${monitor['Name']}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final streamUrl = _zoneminderService.getStreamUrl(monitorId);
                    debugPrint('Stream URL: $streamUrl');

                    return Card(
                      elevation: 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MjpegView(
                            streamUrl: streamUrl,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                monitor['Name'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Setup',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
        ],
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/monitors');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/events');
              break;
          }
        },
      ),
    );
  }
}
