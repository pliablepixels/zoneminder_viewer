import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
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
  late final ZoneMinderService _zoneminderService;
  List<Map<String, dynamic>> _monitors = [];
  bool _isLoading = true;
  bool _isInitialLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _zoneminderService = Provider.of<ZoneMinderService>(context, listen: false);
    _zoneminderService.addListener(_onServiceChanged);
    _fetchMonitors();
  }
  
  @override
  void dispose() {
    _zoneminderService.removeListener(_onServiceChanged);
    super.dispose();
  }
  
  void _onServiceChanged() {
    if (mounted) {
      setState(() {
        _monitors.clear();
        _isLoading = true;
        _isInitialLoad = true;
        _error = null;
      });
      _fetchMonitors();
    }
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    
    return GridView.builder(
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
                      const Text(
                        'Invalid Monitor',
                        style: TextStyle(
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
        
        // Get the stream URL as a Future<String>
        final streamUrl = _zoneminderService.getStreamUrl(monitorId);
        debugPrint('Stream URL requested for monitor $monitorId');

        return Card(
          elevation: 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<String>(
                future: streamUrl,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading stream: ${snapshot.error}'),
                    );
                  } else if (snapshot.hasData) {
                    return MjpegView(
                      streamUrl: Future.value(snapshot.data!),
                      fit: BoxFit.cover,
                    );
                  } else {
                    return const Center(child: Text('No stream available'));
                  }
                },
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
    );
  }
}
