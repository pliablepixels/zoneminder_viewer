import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/zoneminder_service.dart';
import 'views/wizard_view.dart';
import 'views/monitor_view.dart';
import 'views/events_view.dart';

void main() {
  // Initialize logging with enhanced output
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final time = record.time.toLocal().toString().split(' ')[1];
    final level = record.level.name.padRight(7);
    final loggerName = record.loggerName.padRight(20);
    debugPrint('$time $level [${record.loggerName}] ${record.message}');
  });

  runApp(const ZoneMinderApp());
}

class ZoneMinderApp extends StatefulWidget {
  const ZoneMinderApp({super.key});

  @override
  State<ZoneMinderApp> createState() => _ZoneMinderAppState();
}

class _ZoneMinderAppState extends State<ZoneMinderApp> {
  final ZoneMinderService _zmService = ZoneMinderService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  static final Logger _logger = Logger('ZoneMinderApp');

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      await _zmService.initialize();
      final prefs = await SharedPreferences.getInstance();
      final hasToken = prefs.getString('zoneminder_access_token') != null;
      
      if (mounted) {
        setState(() {
          _isLoggedIn = hasToken && _zmService.isAuthenticated;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.severe('Error checking auth status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'ZoneMinder Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4A5568),
          secondary: const Color(0xFF2D3748),
          background: const Color(0xFF1A202C),
          surface: const Color(0xFF2D3748),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A202C),
        cardTheme: const CardThemeData(
          color: Color(0xFF2D3748),
          elevation: 4,
        ),
      ),
      home: _isLoggedIn 
        ? const HomeScreen()
        : const WizardView(),
      onGenerateRoute: (settings) {
        if (settings.name == '/wizard') {
          return MaterialPageRoute(builder: (context) => const WizardView());
        }
        return null;
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => _isLoggedIn ? const HomeScreen() : const WizardView(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  
  const HomeScreen({
    super.key,
    this.initialIndex = 1, // Default to monitors view
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }
  
  final List<Widget> _widgetOptions = [
    const WizardView(),
    const MonitorView(),
    const EventsView(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZoneMinder Viewer'),
        backgroundColor: Colors.grey[900],
      ),
      body: _widgetOptions[_selectedIndex],
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
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), 
    );
  }
}
