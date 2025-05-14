@echo off
echo Fixing service_request_card.dart...

echo Fixing client_details_screen.dart...
type d:\bilink\client_details_clean_fix.dart > d:\bilink\lib\screens\client_details_screen.dart.bak

:: Replace the _openWhatsApp method with a fixed version
powershell -Command "(Get-Content d:\bilink\lib\screens\client_details_screen.dart.bak) -replace '  // دالة لفتح محادثة واتساب مع العميل(\r\n|\n)  Future<void> _openWhatsApp\(String phoneNumber\) async \{(\r\n|\n).*?(\r\n|\n)    // إضافة رمز الدولة إذا لم يكن موجوداً.*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n)    // إنشاء رابط واتساب مع نص ترحيبي(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n).*?(\r\n|\n)  \}', '  // دالة لفتح محادثة واتساب مع العميل$1  Future<void> _openWhatsApp(String phoneNumber) async {$1    try {$1      // Clean up the phone number - remove any non-digit characters$1      String cleanNumber = phoneNumber.replaceAll(RegExp(r''\\D''), '''');$1      $1      // Format for Algeria country code (213)$1      if (!cleanNumber.startsWith(''213'') && !cleanNumber.startsWith(''+213'')) {$1        // Remove leading zero if present$1        if (cleanNumber.startsWith(''0'')) {$1          cleanNumber = cleanNumber.substring(1);$1        }$1        // Add country code$1        cleanNumber = ''213'' + cleanNumber;$1      }$1      $1      // Create WhatsApp URL with greeting message$1      final message = Uri.encodeComponent(''مرحباً، أنا مزود خدمة من تطبيق BiLink'');$1      final whatsappUrl = ''https://wa.me/'' + cleanNumber + ''?text='' + message;$1      $1      // Launch WhatsApp$1      final uri = Uri.parse(whatsappUrl);$1      await launchUrl(uri, mode: LaunchMode.externalApplication);$1    } catch (e) {$1      if (mounted) {$1        ScaffoldMessenger.of(context).showSnackBar($1          const SnackBar($1            content: Text(''لا يمكن فتح تطبيق واتساب''),$1            backgroundColor: Colors.red,$1          ),$1        );$1      }$1    }$1  }' | Out-File -Encoding utf8 d:\bilink\lib\screens\client_details_screen.dart"

echo Fixes applied successfully!
echo Run with "flutter run" to test the application.
