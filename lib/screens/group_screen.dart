import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:globalchat/screens/chatroom_screen.dart';
import 'package:provider/provider.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  void showCreateGroup() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    List<String> selectedUsers = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
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
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Create New Group",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      TextField(
                          controller: nameController,
                          decoration: const InputDecoration(hintText: "Group Name")),
                      const SizedBox(height: 10),
                      TextField(
                          controller: descController,
                          decoration: const InputDecoration(hintText: "Description")),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Select Members",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: db.collection("users").snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final currentUserId =
                          Provider.of<UserProvider>(context, listen: false).userId;
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
                           // Skip
                        }
                      }

                      if (users.isEmpty) return const Center(child: Text("No users found"));

                      return ListView.builder(
                        controller: controller,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final userData = users[index];
                          final userId = userData['id']?.toString() ?? "";
                          final isSelected = selectedUsers.contains(userId);
                          final String name = userData['name']?.toString() ?? "Unknown";
                          final String profileImg =
                              userData['profile_image']?.toString() ?? "";

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedUsers.add(userId);
                                } else {
                                  selectedUsers.remove(userId);
                                }
                              });
                            },
                            secondary: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              backgroundImage: profileImg.isNotEmpty
                                  ? NetworkImage(profileImg)
                                  : null,
                              child: profileImg.isEmpty
                                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : "?")
                                  : null,
                            ),
                            title: Text(name),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final desc = descController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter group name")));
                        return;
                      }

                      final userProvider =
                          Provider.of<UserProvider>(context, listen: false);
                      selectedUsers.add(userProvider.userId);

                      final groupRef = await db.collection("chatrooms").add({
                        "chatroom_name": name,
                        "desc": desc,
                        "is_direct": false,
                        "created_by": userProvider.userId,
                        "created_at": FieldValue.serverTimestamp(),
                        "users": selectedUsers,
                      });

                      if (mounted) {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatroomScreen(
                              chatroomId: groupRef.id,
                              chatroomName: name,
                              isDirect: false,
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text("Create Group"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Groups"),
        actions: [
          IconButton(
              onPressed: showCreateGroup, icon: const Icon(Icons.group_add_outlined)),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection("chatrooms")
            .where("is_direct", isEqualTo: false)
            .where("users", arrayContains: userProvider.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("No groups yet. Create one!"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final chatDoc = docs[index];
              final groupData = chatDoc.data() as Map<String, dynamic>?;
              final groupId = chatDoc.id;
              
              if (groupData == null) return const SizedBox();
              
              final String groupName = groupData['chatroom_name']?.toString() ?? "Group";

              return ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatroomScreen(
                        chatroomId: groupId,
                        chatroomName: groupName,
                        isDirect: false,
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Text(groupName.isNotEmpty ? groupName[0].toUpperCase() : "?"),
                ),
                title: Text(groupName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: StreamBuilder<QuerySnapshot>(
                  stream: db
                      .collection("messages")
                      .where("chatroom_id", isEqualTo: groupId)
                      .orderBy("timestamp", descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, msgSnapshot) {
                    String lastMsg = groupData['desc']?.toString() ?? "No messages yet";
                    final msgDocs = msgSnapshot.data?.docs ?? [];
                    if (msgDocs.isNotEmpty) {
                      final data = msgDocs.first.data() as Map<String, dynamic>?;
                      final hasImage =
                          data?['image_url'] != null && data?['image_url'] != "";
                      lastMsg = hasImage
                          ? "📷 Image"
                          : (data?['text']?.toString() ?? "");
                    }
                    return Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[400]),
                    );
                  },
                ),
                trailing: StreamBuilder<QuerySnapshot>(
                  stream: db
                      .collection("messages")
                      .where("chatroom_id", isEqualTo: groupId)
                      .snapshots(),
                  builder: (context, msgSnapshot) {
                    final msgDocs = msgSnapshot.data?.docs ?? [];
                    final unreadCount = msgDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>?;
                      final readBy = data?['read_by'];
                      return readBy is List && !readBy.contains(userProvider.userId);
                    }).length;

                    if (unreadCount == 0) {
                      return const Icon(Icons.arrow_forward_ios, size: 14);
                    }

                    return CircleAvatar(
                      radius: 10,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
