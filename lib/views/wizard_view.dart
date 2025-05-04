import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../services/zoneminder_service.dart';

class WizardView extends StatefulWidget {
  const WizardView({super.key});

  @override
  State<WizardView> createState() => _WizardViewState();
}

class _WizardViewState extends State<WizardView> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController(text: 'https://demo.zoneminder.com');
  final _usernameController = TextEditingController(text: 'x');
  final _passwordController = TextEditingController(text: 'x');
  final _zoneminderService = ZoneMinderService();
  bool _isLoading = false;
  String? _error;
  static final Logger _logger = Logger('WizardView');

  @override
  void initState() {
    super.initState();
    _zoneminderService.initialize();
    _logger.info('WizardView initialized');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _logger.info('Form submitted');
      _logger.info('URL: ${_urlController.text}');
      _logger.info('Username: ${_usernameController.text}');
      
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final url = _urlController.text;
        _logger.info('Setting base URL: $url');
        await _zoneminderService.setBaseUrl(url);

        _logger.info('Attempting login...');
        final response = await _zoneminderService.login(
          _usernameController.text,
          _passwordController.text,
        );

        if (mounted) {
          _logger.info('Successfully connected to ZoneMinder version: ${response['version']}');
          // Navigate to monitors view
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/monitors');
          }
        }
      } catch (e) {
        _logger.severe('Connection error: $e');
        setState(() {
          _error = 'Error: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZoneMinder Setup'),
        backgroundColor: Colors.grey[900],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://demo.zoneminder.com',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a server URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'x',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'x',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Connect'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
