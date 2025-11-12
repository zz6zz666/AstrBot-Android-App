class DependencyManager {
  static final DependencyManager _instance = DependencyManager._internal();

  final Map<Type, dynamic> _services = {};

  factory DependencyManager() {
    return _instance;
  }

  DependencyManager._internal();

  void put<T>(T service) {
    _services[T] = service;
  }

  T find<T>() {
    return _services[T];
  }

  void delete<T>() {
    _services.remove(T);
  }
}

final DM = DependencyManager();
