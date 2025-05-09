// web_entrypoint.dart
import 'package:bilink/main.dart' as entrypoint;
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  // Remove the "#" from URLs on the web.
  usePathUrlStrategy();

  // Start the actual application.
  entrypoint.main();
}
