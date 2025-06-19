import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class RiderSettingsPage extends StatefulWidget {
  const RiderSettingsPage({super.key});

  @override
  State<RiderSettingsPage> createState() => _RiderSettingsPageState();
}

class _RiderSettingsPageState extends State<RiderSettingsPage> {
  bool _isLoading = false;
  bool _hasError = false;
  String _riderName = 'Loading...';
  String _riderEmail = 'Loading...';
  bool _receiveNotifications = true;
  String _preferredCarType = 'Economy';
  final List<String> _carTypes = ['Economy', 'Premium', 'Luxury'];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final ParseUser? currentUser = await ParseUser.currentUser();

      String name = 'Rider Name';
      String email = 'rider@example.com';

      if (currentUser != null) {
        // Fetch from Parse backend if user is logged in
        name = currentUser.get<String>('username') ?? name;
        email = currentUser.get<String>('email') ?? email;
      } else {
        // Fallback to SharedPreferences
        name = prefs.getString('rider_name') ?? name;
        email = prefs.getString('rider_email') ?? email;
      }

      setState(() {
        _riderName = name;
        _riderEmail = email;
        _nameController.text = name;
        _emailController.text = email;
        _receiveNotifications = prefs.getBool('receive_notifications') ?? true;
        _preferredCarType = prefs.getString('preferred_car_type') ?? 'Economy';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      _showSnackBar('Failed to load settings: $e', isError: true);
    }
  }

  Future<void> _saveSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final ParseUser? currentUser = await ParseUser.currentUser();

      await prefs.setString('rider_name', _nameController.text);
      await prefs.setString('rider_email', _emailController.text);
      await prefs.setBool('receive_notifications', _receiveNotifications);
      await prefs.setString('preferred_car_type', _preferredCarType);

      if (currentUser != null) {
        currentUser
          ..set('username', _nameController.text)
          ..set('email', _emailController.text);
        await currentUser.save();
      }

      setState(() {
        _riderName = _nameController.text;
        _riderEmail = _emailController.text;
        _isLoading = false;
      });

      _showSnackBar('Settings saved successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to save settings: $e', isError: true);
    }
  }

  Future<void> _logout() async {
    final ParseUser? currentUser = await ParseUser.currentUser();
    if (currentUser != null) {
      await currentUser.logout();
    }
    Navigator.pushReplacementNamed(context, '/login'); // Adjust route as needed
    _showSnackBar('Logged out successfully');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: const Color(0xFFFFA500),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFA500),
          primary: const Color(0xFFFFA500),
          secondary: Colors.blue[100],
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Rider Settings',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
          backgroundColor: const Color(0xFFFFA500),
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading settings...'),
                  ],
                ),
              )
            : _hasError
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[700],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load settings',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadSettings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      // Notification Preferences
                      AnimatedScale(
                        scale: 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Card(
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: const Text(
                              'Receive Notifications',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              'Get updates on ride status and promotions',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            value: _receiveNotifications,
                            activeColor: const Color(0xFFFFA500),
                            onChanged: (value) {
                              setState(() {
                                _receiveNotifications = value;
                              });
                            },
                          ),
                        ),
                      ),
                      // Preferred Car Type

                      // Save Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ElevatedButton(
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFA500),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Settings',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      // Logout Button
                      AnimatedScale(
                        scale: 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: const Text(
                              'Logout',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.logout,
                              color: Colors.red,
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Logout?'),
                                  content: const Text(
                                    'Are you sure you want to logout?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _logout();
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'Logout',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
