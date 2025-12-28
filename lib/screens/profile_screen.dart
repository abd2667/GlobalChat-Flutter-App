import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image == null) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final fileName = '${userProvider.userId}-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(image.path);

    try {
      final storage = Supabase.instance.client.storage;
      await storage.from('chat_files').upload('profiles/$fileName', file);
      final imageUrl = storage.from('chat_files').getPublicUrl('profiles/$fileName');

      await FirebaseFirestore.instance.collection("users").doc(userProvider.userId).update({
        "profile_image": imageUrl,
      });

      await userProvider.getData(); // Refresh data

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile image updated!")));
      }
    } catch (e) {
      print("Error updating profile image: $e");
    }
  }

  void showEditProfile() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final TextEditingController nameController = TextEditingController(text: userProvider.userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Full Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;

              await FirebaseFirestore.instance.collection("users").doc(userProvider.userId).update({
                "name": newName,
              });
              await userProvider.getData();

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated!")));
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    backgroundImage: userProvider.profileImage != ""
                        ? CachedNetworkImageProvider(userProvider.profileImage)
                        : null,
                    child: userProvider.profileImage == ""
                        ? Text(
                            userProvider.userName.isNotEmpty ? userProvider.userName[0].toUpperCase() : "?",
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: pickImage,
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        radius: 20,
                        child: const Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              userProvider.userName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              userProvider.userEmail,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.person_outline,
                    title: "Full Name",
                    subtitle: userProvider.userName,
                  ),
                  const SizedBox(height: 15),
                  _buildProfileTile(
                    icon: Icons.public,
                    title: "Country",
                    subtitle: userProvider.country,
                  ),
                  const SizedBox(height: 15),
                  _buildProfileTile(
                    icon: Icons.email_outlined,
                    title: "Email",
                    subtitle: userProvider.userEmail,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: showEditProfile,
                    icon: const Icon(Icons.edit_note),
                    label: const Text("Edit Profile"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}