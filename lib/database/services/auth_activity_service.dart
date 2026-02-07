import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';

class AuthActivityService {
  AuthActivityService._();

  static final AuthActivityService instance = AuthActivityService._();

  final FirestoreService _firestore = FirestoreService();
  final Set<String> _autoLoggedUids = <String>{};
  final Map<String, Map<String, String>> _actorCache =
      <String, Map<String, String>>{};
  bool _manualLoginStarted = false;

  String _platformLabel() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  Future<Map<String, String>> _actorFromUser(User user) async {
    final cached = _actorCache[user.uid];
    if (cached != null) return cached;

    final email = (user.email ?? '').trim();
    final displayName = (user.displayName ?? '').trim();
    var resolvedName = '';
    try {
      final profile =
          await _firestore.streamUserProfile(user.uid, email: user.email).first;
      final nickname = (profile?['nama_panggilan'] ?? '').toString().trim();
      if (nickname.isNotEmpty) {
        resolvedName = nickname;
      }
    } catch (_) {}

    if (resolvedName.isEmpty && displayName.isNotEmpty) {
      resolvedName = displayName;
    }
    if (resolvedName.isEmpty && email.isNotEmpty) {
      resolvedName = email.split('@').first;
    }
    if (resolvedName.isEmpty) {
      resolvedName = 'User';
    }

    final actor = <String, String>{
      'uid': user.uid,
      'email': email,
      'name': resolvedName,
    };
    _actorCache[user.uid] = actor;
    return actor;
  }

  String _targetLabel(User user, Map<String, String> actor) {
    final name = (actor['name'] ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email;
    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    return user.uid;
  }

  Future<void> logLogin({
    User? user,
    String source = 'manual',
  }) async {
    final currentUser = user ?? FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final actor = await _actorFromUser(currentUser);
    try {
      await _firestore.logActivity(
        action: 'login',
        category: 'user',
        targetId: currentUser.uid,
        targetLabel: _targetLabel(currentUser, actor),
        meta: {
          'source': source,
          'platform': _platformLabel(),
        },
        actor: actor,
      );
    } catch (_) {}
  }

  void markManualLoginStarted() {
    _manualLoginStarted = true;
  }

  Future<void> logAutoLoginOnAppStart() async {
    if (_manualLoginStarted) return;
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      for (var i = 0; i < 6; i++) {
        if (_manualLoginStarted) return;
        await Future<void>.delayed(const Duration(milliseconds: 400));
        currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) break;
      }
    }
    if (currentUser == null) return;
    if (_autoLoggedUids.contains(currentUser.uid)) return;
    _autoLoggedUids.add(currentUser.uid);
    await logLogin(user: currentUser, source: 'auto_session');
  }

  Future<void> signOutWithActivity({String source = 'manual'}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final actor = await _actorFromUser(currentUser);
      try {
        await _firestore.logActivity(
          action: 'logout',
          category: 'user',
          targetId: currentUser.uid,
          targetLabel: _targetLabel(currentUser, actor),
          meta: {
            'source': source,
            'platform': _platformLabel(),
          },
          actor: actor,
        );
      } catch (_) {}
    }
    await FirebaseAuth.instance.signOut();
  }
}
