import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZoneMinder Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4A5568),  // Slate primary
          secondary: const Color(0xFF2D3748), // Dark slate
          background: const Color(0xFF1A202C), // Dark background
          surface: const Color(0xFF2D3748), // Slate surface
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
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
          case '/wizard':
            return MaterialPageRoute(builder: (context) => const WizardView());
          case '/monitors':
            return MaterialPageRoute(builder: (context) => const MonitorView());
          case '/events':
            return MaterialPageRoute(builder: (context) => const EventsView());
          default:
            return MaterialPageRoute(builder: (context) => const WizardView());
        }
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const WizardView());
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
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
