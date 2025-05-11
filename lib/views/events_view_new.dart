import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:logging/logging.dart';
import '../services/zoneminder_service.dart';
import 'event_playback_screen.dart';
import '../widgets/mjpeg_view.dart';

class EventsView extends StatefulWidget {
  final ZoneMinderService zmService;
  
  const EventsView({
    super.key,
    required this.zmService,
  }) : super();

  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  Map<int, Map<String, dynamic>> _monitorNames = {};
  Set<int> _selectedMonitorIds = {};
  final int _limit = 20;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isInitialLoad = true;
  static final Logger _logger = Logger('EventsView');

  @override
  void initState() {
    super.initState();
    // Add listener for ZoneMinderService changes
    widget.zmService.addListener(_onServiceChanged);
    _loadEvents();
    
    _logger.info('EventsView initialized for server: ${widget.zmService.baseUrl}');
  }

  @override
  void didUpdateWidget(EventsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle widget updates (e.g., when zmService changes)
    if (widget.zmService != oldWidget.zmService) {
      oldWidget.zmService.removeListener(_onServiceChanged);
      widget.zmService.addListener(_onServiceChanged);
      _onServiceChanged();
    }
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed
    if (mounted) {
      widget.zmService.removeListener(_onServiceChanged);
    }
    _events.clear();
    _monitorNames.clear();
    super.dispose();
  }

  // Handle service changes (e.g., when base URL changes)
  void _onServiceChanged() {
    if (mounted) {
      _logger.info('ZoneMinderService changed, refreshing events');
      _logger.info('New server URL: ${widget.zmService.baseUrl}');
      
      // Clear all existing data and state
      setState(() {
        _events.clear();
        _monitorNames.clear();
        _currentPage = 1;
        _hasMore = true;
        _isLoading = false;
        _isInitialLoad = true;
        _error = null;
      });
      
      // Force a complete reload
      if (mounted) {
        _loadEvents();
      }
    }
  }

  Future<void> _loadEvents({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final zmService = Provider.of<ZoneMinderService>(context, listen: false);
      
      // Load monitor names if not already loaded
      if (_monitorNames.isEmpty) {
        _monitorNames = await zmService.getMonitorsMap();
      }
      
      // Calculate the next page to load
      final currentPageRaw = loadMore ? (_events.length ~/ _limit) + 1 : 1;
      final currentPage = currentPageRaw is int ? currentPageRaw : int.tryParse(currentPageRaw.toString()) ?? 1;
      
      // Load events
      final response = await zmService.getEvents(
        page: currentPage,
        limit: _limit,
        monitorIds: _selectedMonitorIds.isNotEmpty ? _selectedMonitorIds.toList() : null,
      );

      final newEvents = (response['events'] as List<dynamic>).cast<Map<String, dynamic>>();
      final totalPagesRaw = response['totalPages'];
      final totalPages = totalPagesRaw is int ? totalPagesRaw : int.tryParse(totalPagesRaw.toString()) ?? 1;

      setState(() {
        if (loadMore) {
          _events.addAll(newEvents);
        } else {
          _events = newEvents;
        }
        _hasMore = (currentPage is int && totalPages is int) ? currentPage < totalPages : false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load events: $e';
      });
      _logger.severe('Error loading events: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    // Implement search if needed
  }

  void _onMonitorFilterChanged(Set<int> selectedIds) {
    setState(() {
      _selectedMonitorIds = selectedIds;
      _isInitialLoad = true;
      _events = [];
    });
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: _monitorNames.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          FilterChip(
                            label: const Text('All Monitors'),
                            selected: _selectedMonitorIds.isEmpty,
                            onSelected: (_) {
                              _onMonitorFilterChanged({});
                            },
                          ),
                          ..._monitorNames.entries.map((entry) {
                            final monitorName = entry.value['Name']?.toString() ?? 'Monitor ${entry.key}';
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: FilterChip(
                                label: Text(monitorName),
                                selected: _selectedMonitorIds.contains(entry.key),
                                onSelected: (selected) {
                                  final newSelection = Set<int>.from(_selectedMonitorIds);
                                  if (selected) {
                                    newSelection.add(entry.key);
                                  } else {
                                    newSelection.remove(entry.key);
                                  }
                                  _onMonitorFilterChanged(newSelection);
                                },
                              ),
                            );
                          }).toList(),
                        ],
                      ),
              ),
            ],
          ),
        ),

        // Error message
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),

        // Loading indicator or empty state
        if (_isLoading && _events.isEmpty)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_events.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No events found'),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadEvents,
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _events.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _events.length) {
                    if (!_hasMore) {
                      return const SizedBox.shrink();
                    }
                    // The loading indicator is now shown when index >= _events.length
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  // Display event item
                  try {
                    final event = _events[index];
                    final eventData = event['Event'] ?? event; // Handle both direct and nested event data
                    final monitorId = eventData['MonitorId'] as int?;
                    
                    String monitorName = 'Unknown Monitor';
                    if (monitorId != null) {
                      final monitorData = _monitorNames[monitorId];
                      monitorName = monitorData?['Name']?.toString() ?? 'Monitor $monitorId';
                    }
                    
                    // Calculate duration if both start and end times are available
                    String duration = 'N/A';
                    if (eventData['StartTime'] != null && eventData['EndTime'] != null) {
                      try {
                        final start = DateTime.parse(eventData['StartTime']);
                        final end = DateTime.parse(eventData['EndTime']);
                        final diff = end.difference(start);
                        duration = '${diff.inSeconds} seconds';
                        if (diff.inMinutes > 0) {
                          duration = '${diff.inMinutes}m ${diff.inSeconds.remainder(60)}s';
                        }
                      } catch (e) {
                        _logger.warning('Error calculating duration: $e');
                      }
                    }

                    final eventId = eventData['Id'] as int?;
                    final zmService = Provider.of<ZoneMinderService>(context, listen: false);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: InkWell(
                        onTap: () => _onEventTap(eventData),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thumbnail
                              if (eventId != null)
                                Container(
                                  width: 100,
                                  height: 75,
                                  child: FutureBuilder<String>(
                                    future: zmService.getEventThumbnailUrl(eventId),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      if (snapshot.hasError || !snapshot.hasData) {
                                        return const Icon(Icons.error_outline, size: 40, color: Colors.grey);
                                      }
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                          image: DecorationImage(
                                            image: NetworkImage(snapshot.data!),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  width: 100,
                                  height: 75,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                ),
                              
                              const SizedBox(width: 12),
                              
                              // Event details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      monitorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (eventData['Cause'] != null && (eventData['Cause'] as String).isNotEmpty)
                                      Text(
                                        '${eventData['Cause']}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    if (eventData['StartTime'] != null)
                                      Text(
                                        '${eventData['StartTime']}'
                                            .replaceFirst('T', ' ')
                                            .replaceFirst(RegExp(r'\.\d+'), ''),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    if (duration != 'N/A')
                                      Text(
                                        'Duration: $duration',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    if (eventData['Frames'] != null)
                                      Text(
                                        'Frames: ${eventData['Frames']} (${eventData['AlarmFrames'] ?? 0} alarm)',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                  ].whereType<Widget>().toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    _logger.severe('Error rendering event: $e');
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.error),
                        title: const Text('Error loading event'),
                        subtitle: Text('Error: $e'),
                      ),
                    );
                  }
                  // The loading indicator is now shown when index >= _events.length
                },
              ),
            ),
          ),
      ],
    );
  }

  void _onEventTap(Map<String, dynamic> eventData) {
    final eventId = eventData['Id'] as int?;
    if (eventId != null) {
      final zmService = Provider.of<ZoneMinderService>(context, listen: false);
      final playbackUrl = zmService.getEventPlaybackUrl(eventId);
      
      final eventInfo = eventData['Event'] ?? eventData;
      final monitorId = eventInfo['MonitorId'] as int?;
      final monitorName = (monitorId != null && _monitorNames[monitorId] != null) 
          ? (_monitorNames[monitorId]!['Name']?.toString() ?? 'Monitor $monitorId')
          : 'Unknown Monitor';
      
      _logger.info('Opening event $eventId from monitor $monitorId ($monitorName)');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventPlaybackScreen(
            eventId: eventId,
            monitorName: monitorName,
            cause: eventInfo['Cause']?.toString(),
            notes: eventInfo['Notes']?.toString(),
            playbackUrl: playbackUrl,
          ),
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
