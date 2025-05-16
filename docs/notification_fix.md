# إصلاح مشكلة عدم ظهور إشعارات طلبات الخدمة المقبولة

## المشكلة
كانت هناك مشكلة في تطبيق BiLink حيث لا تظهر إشعارات طلبات الخدمة المقبولة للعميل عندما يقبل مقدم الخدمة الطلب. تم تحديد سببين رئيسيين:

1. **حقل `isClientNotified` مفقود**: هذا الحقل ضروري لتحديد ما إذا كان العميل قد تم إخطاره بالطلب المقبول أم لا.
2. **حقل `responseDate` مفقود**: هذا الحقل ضروري لتتبع وقت قبول الطلب والتأكد من أنه تم قبوله في آخر 24 ساعة.

## الحل

1. تم التحقق من أن الكود الموجود في `ServiceRequestCard._updateRequestStatus` يقوم بإضافة الحقول المطلوبة عند قبول الطلب:
   ```dart
   if (newStatus == 'accepted') {
     updateData['isClientNotified'] = false;
     updateData['responseDate'] = FieldValue.serverTimestamp();
     updateData['hasUnreadNotification'] = true;
     updateData['lastStatusChangeBy'] = FirebaseAuth.instance.currentUser?.uid ?? '';
   }
   ```

2. تم إنشاء أداة تشخيصية (`fix_service_request_notifications.dart`) للبحث عن طلبات الخدمة المقبولة التي تفتقر إلى هذه الحقول وإصلاحها.

3. تم التأكد من أن خدمة الإشعارات (`ServiceRequestNotificationService`) تستخدم الحقول الصحيحة في استعلاماتها.

## كيفية التحقق من الإصلاح

1. **تشغيل أداة الإصلاح**:
   - قم بتشغيل ملف `run_notification_fixes.bat`
   - هذا سيقوم بتشغيل أداة الإصلاح التي ستبحث عن الطلبات المقبولة التي تفتقر إلى الحقول المطلوبة وإصلاحها
   - ثم ستشغل أداة اختبار الإشعارات للتحقق من عمل النظام

2. **اختبار يدوي**:
   - قم بتسجيل الدخول كمقدم خدمة
   - قم بقبول طلب خدمة معلق
   - قم بتسجيل الخروج ثم تسجيل الدخول كعميل (صاحب الطلب)
   - تحقق من ظهور علامة الإشعار (النقطة الحمراء) على أيقونة الإشعارات في الواجهة الرئيسية

## التفاصيل التقنية

### آلية الإشعارات
1. عندما يقبل مقدم الخدمة طلبًا، يتم تحديث حالة الطلب إلى "accepted" ويتم تعيين الحقول التالية:
   - `isClientNotified` = false (لم يتم إخطار العميل بعد)
   - `responseDate` = الوقت الحالي (تاريخ ووقت القبول)
   - `hasUnreadNotification` = true (هناك إشعار غير مقروء)

2. في واجهة العميل، يتم استخدام `StreamBuilder` للاستماع إلى تدفق البيانات من `ServiceRequestNotificationService.getAcceptedRequestsCount()` لعرض عدد الإشعارات غير المقروءة.

3. عندما ينقر العميل على أيقونة الإشعارات، يتم عرض حوار الطلبات المقبولة ويتم تحديث حالة الطلبات إلى `isClientNotified` = true لإزالة الإشعار.

### استعلامات Firestore
```dart
// استعلام للحصول على عدد الإشعارات غير المقروءة
_firestore
    .collection('service_requests')
    .where('clientId', isEqualTo: userId)
    .where('status', isEqualTo: 'accepted')
    .where('responseDate', isGreaterThan: Timestamp.fromDate(oneDayAgo))
    .where('isClientNotified', isEqualTo: false)
    .snapshots()
    .map((snapshot) => snapshot.docs.length);
```

## ملاحظات إضافية
- إذا استمرت المشكلة، تأكد من أن الطلبات تحتوي على `clientId` صالح ومطابق لمستخدم العميل الحالي.
- تأكد من أن استعلامات Firestore تستخدم اسم المجموعة الصحيح (service_requests).
- إذا لم تظهر الإشعارات على الفور، قد تحتاج إلى إعادة تشغيل التطبيق أو الانتظار لبضع ثوانٍ حتى يتم تحديث البيانات.
