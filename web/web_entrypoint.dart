// web_entrypoint.dart
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:bilink/main.dart' as entrypoint;

void main() {
  // Remove the "#" from URLs on the web.
  usePathUrlStrategy();

  // Start the actual application.
  entrypoint.main();
}
