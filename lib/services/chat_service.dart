import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _userId;

  // مجموعات Firebase
  static const String _chatsCollection = 'chats';
  static const String _messagesCollection = 'messages';

  // المُعرّف الفريد لإنشاء معرفات الملفات
  final _uuid = Uuid();

  ChatService(this._userId);

  // الحصول على مجموعة المحادثات
  CollectionReference get _chats => _firestore.collection(_chatsCollection);

  // الحصول على مجموعة الرسائل في محادثة معينة
  CollectionReference _getChatMessages(String chatId) => _firestore
      .collection(_chatsCollection)
      .doc(chatId)
      .collection(_messagesCollection);

  // الحصول على قائمة المحادثات للمستخدم الحالي
  Stream<List<Chat>> getChats() {
    try {
      // استخدام استعلام بسيط لتجنب الحاجة إلى فهرس مركب
      return _firestore
          .collection(_chatsCollection)
          .where('participantIds', arrayContains: _userId)
          .snapshots()
          .map((snapshot) {
            // فرز البيانات في الذاكرة بدلاً من استخدام orderBy في قاعدة البيانات
            final chats =
                snapshot.docs
                    .map((doc) => Chat.fromFirestore(doc, _userId))
                    .toList();

            // فرز يدوي حسب وقت آخر رسالة
            chats.sort(
              (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
            );

            return chats;
          });
    } catch (e) {
      print('Error getting chats: $e');
      return Stream.value([]);
    }
  }

  // الحصول على تفاصيل محادثة محددة
  Stream<Chat?> getChatDetails(String chatId) {
    return _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists ? Chat.fromFirestore(doc, _userId) : null);
  }

  // الحصول على رسائل محادثة معينة
  Stream<List<Message>> getChatMessages(String chatId) {
    return _getChatMessages(chatId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList(),
        );
  }

  // إرسال رسالة نصية
  Future<void> sendMessage(
    String chatId,
    String receiverId,
    String message,
  ) async {
    // إنشاء الرسالة
    final messageDoc = _getChatMessages(chatId).doc();
    final newMessage = Message(
      id: messageDoc.id,
      chatId: chatId,
      senderId: _userId,
      receiverId: receiverId,
      text: message,
      timestamp: DateTime.now(),
    );

    // إضافة الرسالة إلى مجموعة الرسائل
    await messageDoc.set(newMessage.toFirestore());

    // تحديث معلومات المحادثة
    await _updateChatInfo(chatId, message, receiverId);
  }

  // إرسال صورة
  Future<void> sendImageMessage(
    String chatId,
    String receiverId,
    File imageFile,
  ) async {
    try {
      // رفع الصورة إلى Firebase Storage
      final imageName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref('chat_images/$chatId/$imageName');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => null);
      final imageUrl = await snapshot.ref.getDownloadURL();

      // إنشاء الرسالة
      final messageDoc = _getChatMessages(chatId).doc();
      final newMessage = Message(
        id: messageDoc.id,
        chatId: chatId,
        senderId: _userId,
        receiverId: receiverId,
        text: 'صورة',
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
      );

      // إضافة الرسالة إلى مجموعة الرسائل
      await messageDoc.set(newMessage.toFirestore());

      // تحديث معلومات المحادثة
      await _updateChatInfo(chatId, 'صورة', receiverId);
    } catch (e) {
      print('فشل إرسال الصورة: $e');
      rethrow;
    }
  }

  // تحديث معلومات المحادثة بعد إرسال رسالة جديدة
  Future<void> _updateChatInfo(
    String chatId,
    String lastMessage,
    String receiverId,
  ) async {
    final chatDoc = _chats.doc(chatId);
    final chatSnapshot = await chatDoc.get();

    if (chatSnapshot.exists) {
      // تحديث المحادثة الموجودة
      await chatDoc.update({
        'lastMessage': lastMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': _userId,
        'unreadCount_$receiverId': FieldValue.increment(1),
      });
    }
  }

  // إنشاء محادثة جديدة
  Future<String> createChat({
    required String receiverId,
    required String receiverName,
    String? receiverImage,
    required String senderName,
    String? senderImage,
    String? serviceId,
    String? serviceTitle,
  }) async {
    // إنشاء معرف محادثة فريد
    final chatId = Chat.createChatId(_userId, receiverId);

    // التحقق من وجود المحادثة مسبقاً
    final chatDoc = _chats.doc(chatId);
    final chatSnapshot = await chatDoc.get();

    if (!chatSnapshot.exists) {
      // إنشاء بيانات المحادثة الجديدة
      await chatDoc.set({
        'participantIds': [_userId, receiverId],
        'participants': {
          _userId: {'name': senderName, 'profileImage': senderImage},
          receiverId: {'name': receiverName, 'profileImage': receiverImage},
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'unreadCount_$_userId': 0,
        'unreadCount_$receiverId': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'serviceId': serviceId,
        'serviceTitle': serviceTitle,
      });
    }

    return chatId;
  }

  // تحديث حالة قراءة الرسائل
  Future<void> markChatAsRead(String chatId) async {
    try {
      // تحديث حالة المحادثة (عداد الرسائل غير المقروءة)
      await _chats.doc(chatId).update({'unreadCount_$_userId': 0});

      // الطريقة المعدلة لتجنب استخدام استعلام مركب يتطلب فهرس خاص
      // جلب جميع الرسائل أولاً ثم فلترتها في الذاكرة
      final allMessages = await _getChatMessages(chatId).get();

      // فلترة الرسائل التي تم استلامها ولم يتم قراءتها بعد
      final unreadDocs =
          allMessages.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['receiverId'] == _userId && data['isRead'] == false;
          }).toList();

      // تحديث كل رسالة على حدة
      if (unreadDocs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in unreadDocs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      print('فشل تحديث حالة القراءة: $e');
    }
  }

  // حذف محادثة
  Future<void> deleteChat(String chatId) async {
    try {
      // حذف جميع الرسائل في المحادثة
      final messages = await _getChatMessages(chatId).get();
      final batch = _firestore.batch();

      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // حذف المحادثة نفسها
      batch.delete(_chats.doc(chatId));

      await batch.commit();
    } catch (e) {
      print('فشل حذف المحادثة: $e');
      rethrow;
    }
  }

  // حذف رسالة واحدة
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _getChatMessages(chatId).doc(messageId).delete();

      // إذا كانت هذه آخر رسالة، تحديث آخر رسالة في المحادثة
      final messages =
          await _getChatMessages(
            chatId,
          ).orderBy('timestamp', descending: true).limit(1).get();

      if (messages.docs.isNotEmpty) {
        final lastMessage = Message.fromFirestore(messages.docs.first);
        await _chats.doc(chatId).update({
          'lastMessage': lastMessage.text,
          'lastMessageTime': lastMessage.timestamp,
          'lastSenderId': lastMessage.senderId,
        });
      } else {
        // إذا لم تبق أي رسائل
        await _chats.doc(chatId).update({
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': '',
        });
      }
    } catch (e) {
      print('فشل حذف الرسالة: $e');
      rethrow;
    }
  }
}
