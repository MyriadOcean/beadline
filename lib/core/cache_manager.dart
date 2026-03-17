import 'dart:async';
import 'dart:collection';
import 'dart:ui';

/// Generic cache manager for frequently accessed data
/// Requirements: Performance optimization
class CacheManager<K, V> {
  CacheManager({int maxSize = 100, Duration ttl = const Duration(minutes: 5)})
    : _maxSize = maxSize,
      _ttl = ttl;
  final int _maxSize;
  final Duration _ttl;
  final LinkedHashMap<K, _CacheEntry<V>> _cache = LinkedHashMap();

  /// Get a value from cache
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // Check if expired
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }

    // Move to end (LRU)
    _cache.remove(key);
    _cache[key] = entry;

    return entry.value;
  }

  /// Put a value in cache
  void put(K key, V value) {
    // Remove if exists to update position
    _cache.remove(key);

    // Evict oldest if at capacity
    while (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(_ttl),
    );
  }

  /// Get or compute a value
  Future<V> getOrCompute(K key, Future<V> Function() compute) async {
    final cached = get(key);
    if (cached != null) return cached;

    final value = await compute();
    put(key, value);
    return value;
  }

  /// Get or compute a value synchronously
  V getOrComputeSync(K key, V Function() compute) {
    final cached = get(key);
    if (cached != null) return cached;

    final value = compute();
    put(key, value);
    return value;
  }

  /// Remove a value from cache
  void remove(K key) {
    _cache.remove(key);
  }

  /// Clear all cached values
  void clear() {
    _cache.clear();
  }

  /// Remove expired entries
  void evictExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => now.isAfter(entry.expiresAt));
  }

  /// Number of items in cache
  int get length => _cache.length;

  /// Whether cache contains a key
  bool containsKey(K key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return false;
    }
    return true;
  }
}

class _CacheEntry<V> {
  _CacheEntry({required this.value, required this.expiresAt});
  final V value;
  final DateTime expiresAt;
}

/// Specialized cache for Song Units
class SongUnitCache extends CacheManager<String, dynamic> {
  SongUnitCache() : super(maxSize: 200, ttl: const Duration(minutes: 10));
}

/// Specialized cache for Tags
class TagCache extends CacheManager<String, dynamic> {
  TagCache() : super(maxSize: 500, ttl: const Duration(minutes: 30));
}

/// Specialized cache for search results
class SearchCache extends CacheManager<String, List<dynamic>> {
  SearchCache() : super(maxSize: 50, ttl: const Duration(minutes: 2));
}

/// Debouncer for search and other frequent operations
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});
  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Throttler for rate-limiting operations
class Throttler {
  Throttler({this.interval = const Duration(milliseconds: 100)});
  final Duration interval;
  DateTime? _lastRun;

  void run(VoidCallback action) {
    final now = DateTime.now();
    if (_lastRun == null || now.difference(_lastRun!) >= interval) {
      _lastRun = now;
      action();
    }
  }
}

/// Lazy loader for paginated data
class LazyLoader<T> {
  LazyLoader({required this.loadPage, this.pageSize = 50});
  final Future<List<T>> Function(int page, int pageSize) loadPage;
  final int pageSize;

  final List<T> _items = [];
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  int get itemCount => _items.length;

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    try {
      final newItems = await loadPage(_currentPage, pageSize);
      _items.addAll(newItems);
      _hasMore = newItems.length >= pageSize;
      _currentPage++;
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() async {
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    await loadMore();
  }

  void clear() {
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _isLoading = false;
  }
}
