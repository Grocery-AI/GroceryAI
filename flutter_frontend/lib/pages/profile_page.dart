import 'package:flutter/material.dart';
import '../themes/colors.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _currentUsername;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initUsername();
  }

  Future<void> _initUsername() async {
    try {
      final token = await storage.read(key: 'token');
      if (token != null) {
        _currentUsername = getUsernameFromToken(token) ?? 'User';
      }
    } catch (e) {
      print('Error loading username: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    try {
      await storage.delete(key: 'token');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  Future<void> _changeAvatar() async {
    try {
      final imageFile = await ImageService.showImagePickerDialog(context);
      if (imageFile != null) {
        final isValid = await ImageService.isImageSizeValid(imageFile);
        if (!isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Image size must be less than 5MB')),
            );
          }
          return;
        }

        // TODO: backend API to upload avatar
        // final base64Image = await ImageService.imageToBase64(imageFile);
        // await apiClient.updateUserAvatar(base64Image);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Avatar updated successfully')),
          );
        }
      }
    } catch (e) {
      print('Error changing avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change avatar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Boska',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF064E3B),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar with Edit Button
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _currentUsername[0].toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Boska',
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Edit Button at Bottom Right
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _changeAvatar,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: kSecondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Username
                  Text(
                    _currentUsername,
                    style: TextStyle(
                      fontFamily: 'Boska',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                  SizedBox(height: 30),

                  // Settings Section
                  _buildSettingTile(
                    icon: Icons.brightness_6,
                    title: 'Theme',
                    subtitle: 'Light Mode',
                    onTap: () {},
                  ),
                  _buildSettingTile(
                    icon: Icons.smart_toy,
                    title: 'AI Model',
                    subtitle: 'Default Model',
                    onTap: () {},
                  ),
                  _buildSettingTile(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {},
                  ),
                  SizedBox(height: 30),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          fontFamily: 'Boska',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ListTile(
        leading: Icon(icon, color: kPrimary),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Boska',
            fontWeight: FontWeight.w400,
            color: kTextDark,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontFamily: 'Boska')),
        trailing: Icon(Icons.chevron_right, color: kTextGray),
        onTap: onTap,
      ),
    );
  }
}
