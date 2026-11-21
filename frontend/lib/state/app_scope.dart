import 'package:material_ui/material_ui.dart';

import 'app_controller.dart';

/// Makes the [AppController] available to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  /// Subscribes: the caller rebuilds when the controller notifies.
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// One-off read for callbacks; does not subscribe.
  static AppController read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
