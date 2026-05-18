import 'package:shared_preferences/shared_preferences.dart';

class VanInvoiceNumberStorage {
  VanInvoiceNumberStorage._();

  static final VanInvoiceNumberStorage instance =
      VanInvoiceNumberStorage._();

  static const String _nextNumberKey = 'van_invoice_next_number';

  SharedPreferences? _preferences;
  Future<void>? _loadFuture;
  bool _isLoaded = false;

  Future<void> ensureLoaded() {
    if (_isLoaded) {
      return Future<void>.value();
    }

    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();
    _isLoaded = true;
  }

  Future<int> peekNextNumber() async {
    await ensureLoaded();
    final value = _preferences?.getInt(_nextNumberKey) ?? 1;
    return value < 1 ? 1 : value;
  }

  Future<String> peekNextInvoiceNumber() async {
    return formatInvoiceNumber(await peekNextNumber());
  }

  Future<String> nextInvoiceNumber() async {
    final nextNumber = await peekNextNumber();
    await _preferences?.setInt(_nextNumberKey, nextNumber + 1);
    return formatInvoiceNumber(nextNumber);
  }

  Future<void> consumeNextNumber() async {
    final nextNumber = await peekNextNumber();
    await _preferences?.setInt(_nextNumberKey, nextNumber + 1);
  }

  Future<void> resetNextNumber() async {
    await ensureLoaded();
    await _preferences?.setInt(_nextNumberKey, 1);
  }

  String formatInvoiceNumber(int number) {
    final normalized = number < 1 ? 1 : number;
    if (normalized <= 9999) {
      return 'VM-${normalized.toString().padLeft(4, '0')}';
    }
    return 'VM-$normalized';
  }
}
