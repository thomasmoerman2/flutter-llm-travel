import 'package:firebase_auth/firebase_auth.dart';

class ReturnObject {
  User? user;
  bool works;
  String errorMessage;

  ReturnObject({
    required this.user,
    required this.works,
    required this.errorMessage,
  });
}

class AuthService {
  Future<ReturnObject?> createUserWithEmailAndPassword(
    String email,
    String password,
    String repeatPassword,
  ) async {
    try {
      if (password != repeatPassword) {
        print('Passwords do not match');
        return null;
      }
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      ReturnObject obj = new ReturnObject(
        user: userCredential.user,
        works: true,
        errorMessage: "",
      );
      return obj;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return new ReturnObject(
          user: null,
          works: false,
          errorMessage: "The password provided is too weak.",
        );
      } else if (e.code == 'email-already-in-use') {
        return new ReturnObject(
          user: null,
          works: false,
          errorMessage: "The account already exists for that email.",
        );
      }
      return new ReturnObject(
        user: null,
        works: false,
        errorMessage: e.toString(),
      );
    } catch (e) {
      return new ReturnObject(
        user: null,
        works: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<ReturnObject?> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      ReturnObject obj = new ReturnObject(
        user: userCredential.user,
        works: true,
        errorMessage: "",
      );
      return obj;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return new ReturnObject(
          user: null,
          works: false,
          errorMessage: "No user found for that email.",
        );
      } else if (e.code == 'wrong-password') {
        return new ReturnObject(
          user: null,
          works: false,
          errorMessage: "Wrong password provided for that user.",
        );
      }
      return new ReturnObject(
        user: null,
        works: false,
        errorMessage: e.toString(),
      );
    } catch (e) {
      return new ReturnObject(
        user: null,
        works: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  Stream<User?> authStateChanges() {
    return FirebaseAuth.instance.authStateChanges();
  }

  Future<bool> updateDisplayName(String displayName) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating display name: $e');
      return false;
    }
  }
}