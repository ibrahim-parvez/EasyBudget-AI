// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // === Auth ===
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

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
    if (gUser == null) return null; // user cancelled

    final GoogleSignInAuthentication gAuth = await gUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: gAuth.idToken,
      accessToken: gAuth.accessToken,
    );

    final cred = await _auth.signInWithCredential(credential);

    // Ensure user document exists
    final uid = cred.user!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(uid).set({
        'name': cred.user!.displayName ?? '',
        'email': cred.user!.email ?? '',
        'households': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return cred;
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
