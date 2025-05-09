import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final String? imageUrl;
  final bool isRead;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageUrl,
    this.isRead = false,
    required this.timestamp,
  });

  // تحويل من Firestore إلى موديل
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Message(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      isRead: data['isRead'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  // تحويل من موديل إلى بيانات Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'isRead': isRead,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

class Chat {
  final String id;
  final String userId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;
  final String lastMessage;
  final bool hasUnreadMessages;
  final DateTime lastMessageTime;
  final String? serviceId;
  final String? serviceTitle;

  Chat({
    required this.id,
    required this.userId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
    required this.lastMessage,
    required this.hasUnreadMessages,
    required this.lastMessageTime,
    this.serviceId,
    this.serviceTitle,
  });

  // إنشاء معرف محادثة فريد من معرفي المستخدمين
  static String createChatId(String uid1, String uid2) {
    // نرتب المعرفات بترتيب أبجدي لضمان الحصول على نفس المعرف بغض النظر عن ترتيب المستخدمين
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  // تحويل من Firestore إلى موديل
  factory Chat.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // تحديد معرف المستخدم الآخر
    List<String> participantIds =
        (data['participantIds'] as List).cast<String>();
    String otherUserId = participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    Map<String, dynamic> participants =
        data['participants'] as Map<String, dynamic>;
    String otherUserName = participants[otherUserId]?['name'] ?? 'مستخدم';
    String? otherUserImage = participants[otherUserId]?['profileImage'];

    return Chat(
      id: doc.id,
      userId: currentUserId,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserImage: otherUserImage,
      lastMessage: data['lastMessage'] ?? '',
      hasUnreadMessages: data['unreadCount_$currentUserId'] > 0,
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      serviceId: data['serviceId'],
      serviceTitle: data['serviceTitle'],
    );
  }
}
