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
        name = currentUser.get<String>('username') ?? name;
        email = currentUser.get<String>('email') ?? email;
      } else {
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
    Navigator.pushReplacementNamed(context, '/login');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFA500),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.red[700]),
                      const SizedBox(height: 16),
                      const Text('Failed to load settings'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadSettings,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Account',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.email),
                            title: TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Preferences',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.notifications),
                            title: const Text('Receive Notifications'),
                            subtitle:
                                const Text('Get updates on rides and offers'),
                            value: _receiveNotifications,
                            activeColor: const Color(0xFFFFA500),
                            onChanged: (value) {
                              setState(() {
                                _receiveNotifications = value;
                              });
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.directions_car),
                            title: const Text('Preferred Car Type'),
                            trailing: DropdownButton<String>(
                              value: _preferredCarType,
                              items: _carTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _preferredCarType = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'App',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          'Logout',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.red),
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Logout?'),
                              content: const Text(
                                  'Are you sure you want to logout?'),
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
                  ],
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFA500),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save Settings', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
