import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:globalchat/screens/chatroom_screen.dart';
import 'package:globalchat/screens/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:globalchat/screens/splash_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  var db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
  }

  Future<void> startDirectChat(Map<String, dynamic> otherUser) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String currentUserId = userProvider.userId.isNotEmpty 
        ? userProvider.userId 
        : (FirebaseAuth.instance.currentUser?.uid ?? "");
    
    final String otherUserId = otherUser['id']?.toString() ?? "";
    
    if (otherUserId.isEmpty || currentUserId.isEmpty) return;

    // Generate a unique ID for 1-on-1 chat
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatroomId = ids.join("_");

    // Check if chatroom already exists, if not create it
    final chatroomDoc = await db.collection("chatrooms").doc(chatroomId).get();

    if (!chatroomDoc.exists) {
      await db.collection("chatrooms").doc(chatroomId).set({
        "chatroom_name": otherUser['name'] ?? "User",
        "desc": "Direct Message",
        "is_direct": true,
        "users": ids,
        "created_at": FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatroomScreen(
            chatroomName: otherUser['name']?.toString() ?? "User",
            chatroomId: chatroomId,
            isDirect: true,
            otherUserImage: otherUser['profile_image']?.toString(),
          ),
        ),
      );
    }
  }

  void showSearchUsers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(5))),
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("Find Friends", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: db.collection("users").snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    
                    final currentUserId = Provider.of<UserProvider>(context, listen: false).userId;
                    final docs = snapshot.data?.docs ?? [];
                    final List<Map<String, dynamic>> users = [];

                    for (var doc in docs) {
                      try {
                        final data = Map<String, dynamic>.from(doc.data() as Map);
                        data['id'] = doc.id;
                        if (data['id'] != currentUserId) {
                          users.add(data);
                        }
                      } catch (e) {
                         // Skip corrupted docs
                      }
                    }

                    if (users.isEmpty) return const Center(child: Text("No users found"));

                    return ListView.builder(
                      controller: controller,
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userData = users[index];
                        final String name = userData['name']?.toString() ?? "Unknown";
                        final String profileImage = userData['profile_image']?.toString() ?? "";
                        final String country = userData['country']?.toString() ?? "";

                        return ListTile(
                          onTap: () {
                            Navigator.pop(context);
                            startDirectChat(userData);
                          },
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            backgroundImage: profileImage.isNotEmpty
                                ? CachedNetworkImageProvider(profileImage)
                                : null,
                            child: profileImage.isEmpty
                                ? Text(name.isNotEmpty ? name[0].toUpperCase() : "?")
                                : null,
                          ),
                          title: Text(name),
                          subtitle: Text(country),
                          trailing: const Icon(Icons.message_outlined, size: 20),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("GlobalChat"),
        actions: [
          IconButton(onPressed: showSearchUsers, icon: const Icon(Icons.search)),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: userProvider.profileImage.isNotEmpty
                    ? CachedNetworkImageProvider(userProvider.profileImage)
                    : null,
                child: userProvider.profileImage.isEmpty
                    ? Text(userProvider.userName.isNotEmpty ? userProvider.userName[0].toUpperCase() : "?",
                        style: const TextStyle(color: Colors.white, fontSize: 24))
                    : null,
              ),
              accountName: Text(userProvider.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(userProvider.userEmail),
            ),
            ListTile(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              },
              leading: const Icon(Icons.person_outline),
              title: const Text("Profile"),
            ),
            const Spacer(),
            ListTile(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SplashScreen()),
                    (route) => false,
                  );
                }
              },
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection("chatrooms")
            .where("users", arrayContains: userProvider.userId)
            .where("is_direct", isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  const Text("No active chats", style: TextStyle(color: Colors.grey, fontSize: 18)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: showSearchUsers,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(150, 45)),
                    child: const Text("Find Friends"),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemBuilder: (BuildContext context, int index) {
              final chatroomDoc = docs[index];
              final chatroom = chatroomDoc.data() as Map<String, dynamic>?;
              final chatroomId = chatroomDoc.id;
              
              if (chatroom == null) return const SizedBox();
              
              final isDirect = chatroom["is_direct"] ?? false;
              final List usersList = chatroom['users'] as List? ?? [];
              final otherUserId = usersList.firstWhere((id) => id != userProvider.userId, orElse: () => "");

              if (otherUserId == "") return const SizedBox();

              return StreamBuilder<DocumentSnapshot>(
                stream: db.collection("users").doc(otherUserId).snapshots(),
                builder: (context, userSnapshot) {
                  String chatroomName = chatroom["chatroom_name"]?.toString() ?? "User";
                  String? profileImg;

                  if (userSnapshot.hasData && userSnapshot.data?.exists == true) {
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                    chatroomName = userData?['name']?.toString() ?? chatroomName;
                    profileImg = userData?['profile_image']?.toString();
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatroomScreen(
                              chatroomName: chatroomName,
                              chatroomId: chatroomId,
                              isDirect: isDirect,
                              otherUserImage: profileImg,
                            ),
                          ),
                        );
                      },
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        backgroundImage: profileImg != null && profileImg.isNotEmpty
                            ? CachedNetworkImageProvider(profileImg)
                            : null,
                        child: profileImg == null || profileImg.isEmpty
                            ? Text(
                                chatroomName.isNotEmpty ? chatroomName[0].toUpperCase() : "?",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        chatroomName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: db.collection("messages")
                              .where("chatroom_id", isEqualTo: chatroomId)
                              .orderBy("timestamp", descending: true)
                              .limit(1)
                              .snapshots(),
                          builder: (context, msgSnapshot) {
                            String lastMsg = "Tap to chat";
                            final msgDocs = msgSnapshot.data?.docs ?? [];
                            if (msgDocs.isNotEmpty) {
                              final data = msgDocs.first.data() as Map<String, dynamic>?;
                              final hasImage = data?['image_url'] != null && data?['image_url'] != "";
                              lastMsg = hasImage ? "📷 Image" : (data?['text']?.toString() ?? "");
                            }
                            return Text(
                              lastMsg,
                              style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      trailing: StreamBuilder<QuerySnapshot>(
                        stream: db.collection("messages")
                            .where("chatroom_id", isEqualTo: chatroomId)
                            .snapshots(),
                        builder: (context, msgSnapshot) {
                          final msgDocs = msgSnapshot.data?.docs ?? [];
                          final unreadCount = msgDocs
                              .where((doc) {
                                final data = doc.data() as Map<String, dynamic>?;
                                final readBy = data?['read_by'];
                                return readBy is List && !readBy.contains(userProvider.userId);
                              })
                              .length;

                          if (unreadCount == 0) return const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey);

                          return CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
