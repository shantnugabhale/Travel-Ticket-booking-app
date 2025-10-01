import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthHelper {
  GoogleAuthHelper._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider
          ..addScope('email')
          ..setCustomParameters({'prompt': 'select_account'});
        final cred = await _auth.signInWithPopup(googleProvider);
        await _upsertUserProfile(cred.user);
        return cred;
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final cred = await _auth.signInWithCredential(credential);
        await _upsertUserProfile(cred.user);
        return cred;
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  static Future<void> signOutGoogle() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
      await _auth.signOut();
    } catch (_) {}
  }

  static Future<void> _upsertUserProfile(User? user) async {
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    final snap = await docRef.get();
    final data = <String, dynamic>{
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email,
      'imageUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (snap.exists) {
      await docRef.set(data, SetOptions(merge: true));
    } else {
      await docRef.set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}


