import 'package:flutter/widgets.dart';

import 'app_services.dart';

/// Makes [AppServices] available to every screen below the navigator.
///
/// [services] is null only during the splash screen, while content loads. The
/// scope widget is always present so the navigator keeps its state when the
/// services arrive.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices? services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    final services = scope?.services;
    assert(services != null, 'AppServices are not ready yet.');
    return services!;
  }

  @override
  bool updateShouldNotify(AppScope old) => services != old.services;
}
