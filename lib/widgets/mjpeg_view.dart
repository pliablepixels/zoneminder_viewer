import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer' as developer;

class MjpegView extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;

  const MjpegView({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  Stream<Uint8List>? _stream;
  Timer? _timer;
  bool _isLoading = true;
  String? _error;
  bool _isReconnecting = false;
  final int _reconnectDelay = 5; // seconds
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  // Process MJPEG frame from stream
  Future<Uint8List?> _processMjpegFrame(List<int> data) async {
    try {
      // Look for frame boundary
      final boundary = '--boundarydonotcross'.codeUnits;
      final boundaryIndex = data.indexOf(boundary[0]);
      
      if (boundaryIndex != -1) {
        // Extract frame data
        final frameData = data.sublist(0, boundaryIndex);
        return Uint8List.fromList(frameData);
      }
      return null;
    } catch (e) {
      debugPrint('Error processing MJPEG frame: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stream?.drain();
    _stream = null;
    super.dispose();
  }

  Future<void> _startStream() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _reconnectAttempts = 0;
      });

      final client = http.Client();
      try {
        // Add headers for MJPEG streaming
        final request = http.Request('GET', Uri.parse(widget.streamUrl))
          ..headers['Accept'] = 'multipart/x-mixed-replace;boundary=--boundarydonotcross'
          ..headers['Connection'] = 'keep-alive'
          ..headers['Cache-Control'] = 'no-cache'
          ..headers['Pragma'] = 'no-cache'
          ..headers['User-Agent'] = 'Flutter MJPEG Viewer';

        final response = await client.send(request);

        if (response.statusCode == 200) {
          // Create a controller to handle the stream
          final controller = StreamController<Uint8List>();
          
          // Listen to the response stream
          response.stream.listen(
            (data) async {
              if (mounted) {
                final frame = await _processMjpegFrame(data);
                if (frame != null) {
                  controller.add(frame);
                }
              }
            },
            onError: (error) {
              if (mounted && !_isReconnecting) {
                _isReconnecting = true;
                setState(() {
                  _error = 'Stream Error: $error';
                  _isLoading = true;
                });
                
                // Wait and retry
                Future.delayed(Duration(seconds: _reconnectDelay), () {
                  if (_reconnectAttempts < _maxReconnectAttempts) {
                    _reconnectAttempts++;
                    _startStream();
                  } else {
                    _isReconnecting = false;
                    setState(() {
                      _error = 'Failed to reconnect after $_maxReconnectAttempts attempts';
                      _isLoading = false;
                    });
                  }
                });
              }
              controller.close();
            },
            onDone: () {
              if (mounted && !_isReconnecting) {
                _isReconnecting = true;
                setState(() {
                  _error = 'Stream connection closed';
                  _isLoading = true;
                });
                
                // Wait and retry
                Future.delayed(Duration(seconds: _reconnectDelay), () {
                  if (_reconnectAttempts < _maxReconnectAttempts) {
                    _reconnectAttempts++;
                    _startStream();
                  } else {
                    _isReconnecting = false;
                    setState(() {
                      _error = 'Failed to reconnect after $_maxReconnectAttempts attempts';
                      _isLoading = false;
                    });
                  }
                });
              }
              controller.close();
            },
            cancelOnError: false,
          );

          setState(() {
            _stream = controller.stream;
            _isLoading = false;
          });

          // Start a timer to keep the stream alive
          _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
            if (mounted) {
              setState(() {
                // No-op to trigger a rebuild and keep the stream alive
              });
            }
          });
        } else {
          throw Exception('Failed to get stream: ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (mounted && !_isReconnecting) {
        _isReconnecting = true;
        setState(() {
          _error = 'Initial connection failed: $e';
          _isLoading = false;
        });
        
        // Wait and retry
        Future.delayed(Duration(seconds: _reconnectDelay), () {
          if (_reconnectAttempts < _maxReconnectAttempts) {
            _reconnectAttempts++;
            _startStream();
          } else {
            _isReconnecting = false;
            setState(() {
              _error = 'Failed to reconnect after $_maxReconnectAttempts attempts';
              _isLoading = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return StreamBuilder<Uint8List>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Stream Error: ${snapshot.error}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: widget.fit,
          );
        }

        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}
