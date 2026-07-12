import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/van_text_formatters.dart';

class VanBusinessProfileSummary {
  const VanBusinessProfileSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  VanBusinessProfileSummary copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VanBusinessProfileSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VanBusinessProfileSummary.fromJson(Map<String, dynamic> json) {
    DateTime readDate(String key, {DateTime? fallback}) {
      final raw = json[key]?.toString().trim() ?? '';
      if (raw.isEmpty) {
        return fallback ?? DateTime.now();
      }
      return DateTime.tryParse(raw) ?? (fallback ?? DateTime.now());
    }

    final now = DateTime.now();
    final createdAt = readDate('createdAt', fallback: now);
    final updatedAt = readDate('updatedAt', fallback: createdAt);
    final id = json['id']?.toString().trim() ?? '';
    final name = sanitizeVanText(json['name']).trim();

    return VanBusinessProfileSummary(
      id: id.isEmpty ? VanBusinessProfileScopeStorage.defaultBusinessId : id,
      name: name.isEmpty ? 'Default business' : name,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class VanBusinessProfileScopeStorage extends ChangeNotifier {
  VanBusinessProfileScopeStorage._();

  static final VanBusinessProfileScopeStorage instance =
      VanBusinessProfileScopeStorage._();

  static const String defaultBusinessId = 'default_business';
  static const String _profilesKey = 'van_business_profiles_v1';
  static const String _activeProfileIdKey = 'van_active_business_profile_id_v1';
  static const String _legacyBusinessNameKey = 'van_business_name';
  static const String _publicConfigIdKey =
      'van_booking_link_public_config_id_v1';

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
    await _ensureDefaultProfile();
  }

  Future<List<VanBusinessProfileSummary>> loadProfiles() async {
    await ensureLoaded();
    return _readProfiles();
  }

  Future<VanBusinessProfileSummary> activeProfile() async {
    await ensureLoaded();
    final profiles = _readProfiles();
    final activeId = _preferences?.getString(_activeProfileIdKey)?.trim() ?? '';
    return profiles.firstWhere(
      (profile) => profile.id == activeId,
      orElse: () => profiles.first,
    );
  }

  Future<String> activeBusinessId() async {
    return (await activeProfile()).id;
  }

  Future<bool> isDefaultBusinessActive() async {
    return (await activeBusinessId()) == defaultBusinessId;
  }

  Future<VanBusinessProfileSummary> addProfile(
    String rawName, {
    bool activate = true,
    bool notify = true,
  }) async {
    await ensureLoaded();
    final name = sanitizeVanText(rawName).trim();
    final now = DateTime.now();
    final id = _buildProfileId(name, now);
    final profile = VanBusinessProfileSummary(
      id: id,
      name: name.isEmpty ? 'New business' : name,
      createdAt: now,
      updatedAt: now,
    );
    final profiles = <VanBusinessProfileSummary>[..._readProfiles(), profile];
    await _writeProfiles(profiles);
    if (activate) {
      await _preferences?.setString(_activeProfileIdKey, profile.id);
    }
    if (notify) {
      notifyListeners();
    }
    return profile;
  }

  Future<void> switchProfile(String profileId) async {
    await ensureLoaded();
    final normalizedId = profileId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    final profiles = _readProfiles();
    final exists = profiles.any((profile) => profile.id == normalizedId);
    if (!exists) {
      return;
    }
    await _preferences?.setString(_activeProfileIdKey, normalizedId);
    notifyListeners();
  }

  Future<void> renameProfile({
    required String profileId,
    required String name,
  }) async {
    await ensureLoaded();
    final normalizedId = profileId.trim();
    final cleanedName = sanitizeVanText(name).trim();
    if (normalizedId.isEmpty || cleanedName.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final profiles = _readProfiles()
        .map(
          (profile) => profile.id == normalizedId
              ? profile.copyWith(name: cleanedName, updatedAt: now)
              : profile,
        )
        .toList(growable: false);
    await _writeProfiles(profiles);
    notifyListeners();
  }

  Future<String> scopedLocalKey(String baseKey) async {
    final activeId = await activeBusinessId();
    if (activeId == defaultBusinessId) {
      return baseKey;
    }
    return '${baseKey}_business_$activeId';
  }

  Future<String> bookingLinkPublicConfigId(String ownerUid) async {
    await ensureLoaded();
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return '';
    }
    final businessId = await activeBusinessId();
    final storageKey = await scopedLocalKey(_publicConfigIdKey);
    final saved = _preferences?.getString(storageKey)?.trim() ?? '';
    final expected = businessId == defaultBusinessId
        ? normalizedOwnerUid
        : '${normalizedOwnerUid}_$businessId';
    if (saved == expected) {
      debugPrint(
        '[BusinessProfiles] Booking Link identity loaded businessProfileId=$businessId publicConfigId=$saved',
      );
      return saved;
    }
    await _preferences?.setString(storageKey, expected);
    debugPrint(
      '[BusinessProfiles] Booking Link identity created businessProfileId=$businessId publicConfigId=$expected',
    );
    return expected;
  }

  List<VanBusinessProfileSummary> _readProfiles() {
    final raw = _preferences?.getString(_profilesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <VanBusinessProfileSummary>[_defaultProfile()];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final profiles = <VanBusinessProfileSummary>[];
        for (final item in decoded) {
          if (item is Map) {
            profiles.add(
              VanBusinessProfileSummary.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
        if (profiles.isNotEmpty) {
          final hasDefault = profiles.any(
            (profile) => profile.id == defaultBusinessId,
          );
          return hasDefault
              ? profiles
              : <VanBusinessProfileSummary>[_defaultProfile(), ...profiles];
        }
      }
    } catch (error) {
      debugPrint('[BusinessProfiles] load failed: $error');
    }
    return <VanBusinessProfileSummary>[_defaultProfile()];
  }

  Future<void> _writeProfiles(List<VanBusinessProfileSummary> profiles) async {
    await _preferences?.setString(
      _profilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  Future<void> _ensureDefaultProfile() async {
    final profiles = _readProfiles();
    final hasDefault = profiles.any(
      (profile) => profile.id == defaultBusinessId,
    );
    final normalizedProfiles = hasDefault
        ? profiles
        : <VanBusinessProfileSummary>[_defaultProfile(), ...profiles];
    await _writeProfiles(normalizedProfiles);

    final activeId = _preferences?.getString(_activeProfileIdKey)?.trim() ?? '';
    final activeExists = normalizedProfiles.any(
      (profile) => profile.id == activeId,
    );
    if (!activeExists) {
      await _preferences?.setString(_activeProfileIdKey, defaultBusinessId);
    }
  }

  VanBusinessProfileSummary _defaultProfile() {
    final legacyName = sanitizeVanText(
      _preferences?.getString(_legacyBusinessNameKey),
    ).trim();
    final now = DateTime.now();
    return VanBusinessProfileSummary(
      id: defaultBusinessId,
      name: legacyName.isEmpty ? 'Default business' : legacyName,
      createdAt: now,
      updatedAt: now,
    );
  }

  String _buildProfileId(String name, DateTime now) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final suffix = now.microsecondsSinceEpoch.toString();
    return '${slug.isEmpty ? 'business' : slug}_$suffix';
  }
}
