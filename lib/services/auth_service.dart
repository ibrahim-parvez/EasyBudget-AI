import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // --- Helpers for Apple Sign-In ---
  String _generateNonce([int length = 32]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values).substring(0, length);
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // === Email/Password ===
  Future<UserCredential> signUpWithEmail(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'households': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return cred;
  }

  User? getCurrentUser() => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // === Google ===
  Future<UserCredential?> signInWithGoogle() async {
    final gUser = await _googleSignIn.signIn();
    if (gUser == null) return null;
    final gAuth = await gUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: gAuth.idToken,
      accessToken: gAuth.accessToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(cred);
    return cred;
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      // Generate nonce
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request Apple credentials
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      if (appleCred.identityToken == null) {
        throw FirebaseAuthException(
          code: 'ERROR_MISSING_ID_TOKEN',
          message: 'Apple Sign-In failed: identityToken is null',
        );
      }

      // Create OAuth credential for Firebase
      final oauthCred = OAuthProvider("apple.com").credential(
        idToken: appleCred.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCred.authorizationCode,
      );

      // Sign in with Firebase
      final cred = await _auth.signInWithCredential(oauthCred);

      // Ensure Firestore user document exists
      await _ensureUserDoc(cred, fullName: appleCred.givenName ?? '');

      // Update Firebase displayName if missing
      final user = _auth.currentUser;
      if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
        final fullName = appleCred.givenName ?? '';
        if (fullName.isNotEmpty) {
          await user.updateDisplayName(fullName);
          await user.reload();
        }
      }

      return cred;
    } catch (e) {
      print('Apple Sign-In error: $e');
      rethrow;
    }
  }


  // --- Common ---
  Future<void> _ensureUserDoc(UserCredential? cred, {String fullName = ''}) async {
    final user = cred?.user;
    if (user == null) return; // <-- safely return if no user

    final uid = user.uid;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(uid).set({
        'name': user.displayName ?? fullName,
        'email': user.email ?? '',
        'households': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }


  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // === Households ===
  Future<String> createHousehold(String name, String pin) async {
    final uid = _auth.currentUser!.uid;
    final docRef = _db.collection('households').doc();
    final hid = docRef.id;
    await docRef.set({
      'name': name,
      'pin': pin,
      'createdBy': uid,
      'members': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(uid).update({
      'households': FieldValue.arrayUnion([hid]),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentHousehold', hid);
    return hid;
  }

  Future<bool> joinHouseholdByPin(String pin) async {
    final uid = _auth.currentUser!.uid;
    final q = await _db.collection('households').where('pin', isEqualTo: pin).limit(1).get();
    if (q.docs.isEmpty) return false;
    final hid = q.docs.first.id;
    await _db.collection('households').doc(hid).update({
      'members': FieldValue.arrayUnion([uid])
    });
    await _db.collection('users').doc(uid).update({
      'households': FieldValue.arrayUnion([hid])
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentHousehold', hid);
    return true;
  }

  Future<List<String>> getMyHouseholds() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    final arr = (doc.data()?['households'] as List?)?.cast<String>() ?? [];
    return arr;
  }

  Future<String?> getCurrentHouseholdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentHousehold');
  }

  Future<void> setCurrentHouseholdInPrefs(String hid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentHousehold', hid);
  }

  // === Expenses ===
  Future<void> addExpense({
    required String hid,
    required String title,
    required double amount,
    required String category,
    String? notes,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('households')
      .doc(hid)
      .collection('expenses')
      .add({
        'title': title,
        'amount': amount,
        'category': category,
        'purchasedBy': uid,
        'date': FieldValue.serverTimestamp(),
        'notes': notes ?? '',
      });
  }

  Stream<QuerySnapshot<Map<String,dynamic>>> streamExpenses(String hid) {
    return _db.collection('households').doc(hid)
      .collection('expenses')
      .orderBy('date', descending: true)
      .snapshots();
  }
}
