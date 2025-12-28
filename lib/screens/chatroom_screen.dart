import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:globalchat/screens/image_viewer_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class ChatroomScreen extends StatefulWidget {
  final String chatroomName;
  final String chatroomId;
  final bool isDirect;
  final String? otherUserImage;

  const ChatroomScreen({
    super.key,
    required this.chatroomId,
    required this.chatroomName,
    this.isDirect = false,
    this.otherUserImage,
  });

  @override
  State<ChatroomScreen> createState() => _ChatroomScreenState();
}

class _ChatroomScreenState extends State<ChatroomScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  bool isTyping = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setTypingStatus(bool typing) {
    if (isTyping == typing) return;
    isTyping = typing;
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    db.collection("chatrooms").doc(widget.chatroomId).collection("typing").doc(userId).set({
      "isTyping": typing,
      "name": Provider.of<UserProvider>(context, listen: false).userName,
    });
  }

  Future<String?> uploadImage(String filePath) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(filePath);
    final storage = Supabase.instance.client.storage;

    try {
      print("Starting image upload to Supabase...");
      final response = await storage.from('chat_files').upload('images/$fileName', file);
      print("Upload successful: $response");
      final publicUrl = storage.from('chat_files').getPublicUrl('images/$fileName');
      print("Public URL: $publicUrl");
      return publicUrl;
    } catch (e) {
      print("Detailed Upload Error: $e");
      return null;
    }
  }

  Future<void> pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedImage == null) return;

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading image...")));

    final imageUrl = await uploadImage(pickedImage.path);
    if (imageUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image upload failed. Check connection."), backgroundColor: Colors.redAccent));
      }
      return;
    }

    _broadcastMessage(text: "", imageUrl: imageUrl);
  }

  Future<void> sendMessage() async {
    final String text = messageController.text.trim();
    if (text.isEmpty) return;
    messageController.clear();
    _setTypingStatus(false);
    _broadcastMessage(text: text);
  }

  void _broadcastMessage({required String text, String? imageUrl}) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    Map<String, dynamic> messageData = {
      "text": text,
      "image_url": imageUrl ?? "",
      "sender_name": userProvider.userName,
      "sender_id": userProvider.userId,
      "sender_image": userProvider.profileImage,
      "chatroom_id": widget.chatroomId,
      "timestamp": FieldValue.serverTimestamp(),
      "read_by": [userProvider.userId],
    };
    db.collection("messages").add(messageData);
  }

  // Removed local DB bubble builder

  Widget _buildMessageBubble(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final bool isMe = data['sender_id'] == userProvider.userId;
    final DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();
    final String time = ts != null ? DateFormat('hh:mm a').format(ts) : "";

    // Mark as read if not me
    final readBy = data['read_by'];
    if (!isMe && (readBy is! List || !readBy.contains(userProvider.userId))) {
      db.collection("messages").doc(doc.id).update({
        "read_by": FieldValue.arrayUnion([userProvider.userId])
      });
    }

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: data['sender_image'] != null && data['sender_image'] != ""
                  ? CachedNetworkImageProvider(data['sender_image'])
                  : null,
              child: (data['sender_image'] == null || data['sender_image'] == "")
                  ? Text(
                      (data['sender_name'] != null && data['sender_name'].toString().isNotEmpty)
                          ? data['sender_name'].toString()[0].toUpperCase()
                          : "?",
                      style: const TextStyle(fontSize: 10))
                  : null,
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe && !widget.isDirect)
                Text(
                  data['sender_name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.cyanAccent),
                ),
              if (data['image_url'] != null && data['image_url'] != "")
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageViewerScreen(
                          imageUrl: data['image_url'],
                          heroTag: doc.id,
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: doc.id,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: data['image_url'],
                          placeholder: (context, url) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[900],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              if (data['text'] != "")
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    data['text'],
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: ((data['read_by'] as List?)?.length ?? 0) > 1 ? Colors.cyanAccent : Colors.white.withOpacity(0.6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (widget.isDirect)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: (widget.otherUserImage != null && widget.otherUserImage!.isNotEmpty)
                      ? CachedNetworkImageProvider(widget.otherUserImage!)
                      : null,
                  child: (widget.otherUserImage == null || widget.otherUserImage!.isEmpty)
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chatroomName, style: const TextStyle(fontSize: 16)),
                  StreamBuilder(
                    stream: db.collection("chatrooms").doc(widget.chatroomId).collection("typing").snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final typingUsers = snapshot.data!.docs
                          .where((doc) => doc.id != Provider.of<UserProvider>(context, listen: false).userId && doc['isTyping'] == true)
                          .toList();
                      if (typingUsers.isNotEmpty) {
                        return Text("${typingUsers[0]['name']} is typing...", style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontStyle: FontStyle.italic));
                      }
                      
                      // If not typing, show Online status or Last Seen
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      final otherUserId = widget.isDirect ? widget.chatroomId.split('_').firstWhere((id) => id != userProvider.userId, orElse: () => "") : "none";
                      
                      return StreamBuilder(
                        stream: db.collection("users").doc(otherUserId).snapshots(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData || !widget.isDirect || otherUserId == "" || otherUserId == "none") return const SizedBox();
                          final userData = userSnapshot.data!.data();
                          if (userData == null) return const SizedBox();
                          
                          final status = userData['status'] ?? "Offline";
                          if (status == "Online") {
                            return const Text("Online", style: TextStyle(fontSize: 10, color: Colors.greenAccent));
                          } else {
                            final lastSeen = userData['last_seen'] as Timestamp?;
                            final lastSeenStr = lastSeen != null ? DateFormat('hh:mm a').format(lastSeen.toDate()) : "a long time ago";
                            return Text("Last seen at $lastSeenStr", style: TextStyle(fontSize: 10, color: Colors.grey[400]));
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: db.collection("messages")
                  .where("chatroom_id", isEqualTo: widget.chatroomId)
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No messages yet. Say hi!"));

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  controller: scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildMessageBubble(docs[index]),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(onPressed: pickAndSendImage, icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.deepPurpleAccent)),
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      onChanged: (val) {
                        _setTypingStatus(val.isNotEmpty);
                      },
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        fillColor: Colors.black.withOpacity(0.2),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: sendMessage,
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      radius: 25,
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
