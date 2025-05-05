import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/zoneminder_service.dart';

class EventsView extends StatefulWidget {
  final ZoneMinderService zmService;
  
  const EventsView({
    super.key,
    required this.zmService,
  });

  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  Map<int, String> _monitorNames = {};
  Set<int> _selectedMonitorIds = {};
  final int _limit = 20;
  bool _hasMore = true;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load monitors first
      final monitors = await widget.zmService.getMonitorsMap();
      _monitorNames = monitors.map((key, value) => 
        MapEntry(key, value['Name'] as String? ?? 'Monitor $key')
      );

      // Load events
      await _loadEvents();
    } catch (e) {
      setState(() {
        _error = 'Failed to load events: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadEvents() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get events with current filters
      final events = await widget.zmService.getEvents(
        limit: _limit,
        monitorIds: _selectedMonitorIds.isNotEmpty 
            ? _selectedMonitorIds.toList() 
            : _monitorNames.keys.toList(),
      );

      if (!mounted) return;
      
      setState(() {
        if (_isInitialLoad) {
          _events = events;
        } else {
          _events.addAll(events);
        }
        _hasMore = events.length >= _limit;
        _isInitialLoad = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load events: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: FilterChip(
                                label: Text(entry.value),
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
            child: Center(child: CircularProgressIndicator()),
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
              onRefresh: () {
                setState(() {
                  _isInitialLoad = true;
                  _events = [];
                });
                return _loadEvents();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _events.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _events.length) {
                    if (_hasMore) {
                      _loadEvents();
                      return const Center(child: CircularProgressIndicator());
                    } else {
                      return const SizedBox.shrink();
                    }
                  }

                  final event = _events[index];
                  final eventData = event['Event'] as Map<String, dynamic>? ?? {};
                  final monitorId = eventData['MonitorId'] as int?;
                  final monitorName = monitorId != null
                      ? _monitorNames[monitorId] ?? 'Monitor $monitorId'
                      : 'Unknown Monitor';
                  
                  final startTime = eventData['StartTime'] != null
                      ? DateTime.parse(eventData['StartTime'] as String).toLocal()
                      : null;
                  
                  final endTime = eventData['EndTime'] != null
                      ? DateTime.parse(eventData['EndTime'] as String).toLocal()
                      : null;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: const Icon(Icons.video_library),
                      title: Text(monitorName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (startTime != null)
                            Text('Started: ${_formatDateTime(startTime)}'),
                          if (endTime != null)
                            Text('Ended: ${_formatDateTime(endTime)}'),
                          if (eventData['Frames'] != null)
                            Text('Frames: ${eventData['Frames']}'),
                          if (eventData['AlarmFrames'] != null)
                            Text('Alarm Frames: ${eventData['AlarmFrames']}'),
                        ],
                      ),
                      onTap: () {
                        // TODO: Navigate to event details
                      },
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
