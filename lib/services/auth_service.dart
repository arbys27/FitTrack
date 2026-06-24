import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart' as fb_core;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import '../models/user_model.dart';
import 'email_service.dart';
import 'firebase_user_service.dart';

/// Authentication service using Firebase
class AuthService {
  static final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseUserService _firebaseUserService = FirebaseUserService();

  String? _lastError;
  String? get lastError => _lastError;

  /// Check if user is logged in
  bool get isLoggedIn => fb_core.Firebase.apps.isNotEmpty && _auth.currentUser != null;

  /// Get current user UID
  String? get currentUserId => fb_core.Firebase.apps.isNotEmpty ? _auth.currentUser?.uid : null;

  /// Get current user email
  String? get currentEmail => fb_core.Firebase.apps.isNotEmpty ? _auth.currentUser?.email : null;

  /// Recover account if it exists in Firestore but not in Firebase Auth
  /// This handles cases where users were created in Firestore but Firebase Auth account is missing
  Future<bool> recoverAccountWithoutAuth(String email, String password) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        _lastError = 'Firebase is not initialized';
        return false;
      }

      print('🔐 Attempting account recovery for: $email');

      // Check if email exists in Firestore
      final firestoreSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (firestoreSnapshot.docs.isEmpty) {
        _lastError = 'No account found for this email address';
        print('❌ Email not found in Firestore');
        return false;
      }

      print('✅ Found user in Firestore: $email');

      // Check if email exists in Firebase Auth
      var hasAuthAccount = false;
      try {
        final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
        hasAuthAccount = methods.isNotEmpty;
      } catch (e) {
        print('ℹ️ Firebase Auth account not found (expected): $e');
        hasAuthAccount = false;
      }

      if (hasAuthAccount) {
        _lastError = 'This account already has Firebase authentication';
        print('ℹ️ Account already has auth - use regular login');
        return false;
      }

      // Account exists in Firestore but not in Auth - create the Auth account now
      print('🔧 Creating Firebase Auth account for existing Firestore user...');
      
      if (password.length < 8) {
        _lastError = 'Password must be at least 8 characters';
        return false;
      }

      // Create the Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final userId = userCredential.user!.uid;
      print('✅ Firebase Auth account created. Auth UID: $userId');

      // Update the Firestore document with the correct UID if it's different
      final firestoreUser = firestoreSnapshot.docs.first;
      final existingUid = firestoreUser['uid'] ?? firestoreUser.id;

      if (existingUid != userId) {
        print('⚠️ UID mismatch - updating Firestore document');
        print('Old UID: $existingUid, New UID: $userId');
        
        // Copy data to new UID doc
        await _firestore.collection('users').doc(userId).set(firestoreUser.data());
        
        // Optionally delete old doc if UIDs don't match
        if (existingUid != firestoreUser.id) {
          await firestoreUser.reference.delete();
        }
        print('✅ Firestore updated with correct UID');
      }

      _lastError = null;
      return true;
    } on fb.FirebaseAuthException catch (e) {
      _lastError = _getFirebaseErrorMessage(e.code);
      print('❌ Recovery error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      _lastError = 'Error during recovery: $e';
      print('❌ Unexpected error: $_lastError');
      return false;
    }
  }

  /// Check if account exists in Firestore but not in Firebase Auth (data inconsistency check)
  Future<bool> accountExistsWithoutAuth(String email) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        return false;
      }

      // Check Firebase Auth
      var inAuth = false;
      try {
        final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
        inAuth = methods.isNotEmpty;
      } catch (e) {
        inAuth = false;
      }

      // Check Firestore
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      final inFirestore = snapshot.docs.isNotEmpty;

      // Return true if in Firestore but NOT in Auth (inconsistency found)
      return inFirestore && !inAuth;
    } catch (e) {
      print('Error checking account: $e');
      return false;
    }
  }

  

  /// ============================================
  /// GOOGLE AUTHENTICATION - SIGN IN (LOGIN ONLY)
  /// ============================================
  /// Sign in with Google - ONLY for registered users who have completed registration
  /// This method requires the user to already have a registered account with a Firestore profile
  /// Step 1: Authenticate with Google
  /// Step 2: Verify user exists in Firestore
  /// Step 3: If not registered, sign out and reject login
  Future<bool> signInWithGoogle() async {
    try {
      _lastError = null;

      if (!await _ensureFirebaseInitialized()) {
        _lastError = 'Firebase is not initialized';
        print('❌ Firebase not initialized for Google login');
        return false;
      }

      // Web should use Firebase popup flow directly
      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        print('🔐 [GOOGLE LOGIN] Starting Google authentication via popup...');
        final userCredential = await _auth.signInWithPopup(provider);
        final user = userCredential.user;
        
        if (user == null) {
          _lastError = 'Google sign-in failed';
          print('❌ [GOOGLE LOGIN] Google sign-in failed: user is null');
          return false;
        }

        print('✅ [GOOGLE LOGIN] Google authentication successful');
        print('   UID: ${user.uid}');
        print('   Email: ${user.email}');

        // CRITICAL: Check if user is registered (exists in Firestore)
        // This is the key difference from Google Register - must have Firestore profile
        print('🔍 [GOOGLE LOGIN] Checking if user is registered in Firestore...');
        final isRegistered = await isGoogleUserRegistered(user.uid);
        
        print('📊 [GOOGLE LOGIN] Registration check result: $isRegistered');
        
        if (!isRegistered) {
          // User is authenticated with Google but NOT registered in the app
          print('❌ [GOOGLE LOGIN] User NOT registered in Firestore!');
          print('   UID: ${user.uid}');
          print('   User must register first before logging in');
          print('🔐 [GOOGLE LOGIN] Signing out user...');
          
          try {
            await _auth.signOut();
            print('✅ [GOOGLE LOGIN] Signed out unregistered Google user');
          } catch (e) {
            print('⚠️ [GOOGLE LOGIN] Error signing out: $e');
          }
          
          _lastError = 'This Google account is not registered. Please register first.';
          return false;
        }

        print('✅ [GOOGLE LOGIN] User IS registered in Firestore');
        print('✅ [GOOGLE LOGIN] Google login successful!');
        print('   Ready to show dashboard or profile setup');
        print('   AuthGate will now load the profile and check completion status');
        return true;
      } else {
        // Mobile/Android implementation using google_sign_in package
        print('🔐 [GOOGLE LOGIN] Starting Google authentication via native flow (mobile)...');
        
        try {
          // Attempt to sign in with Google
          final googleUser = await _googleSignIn.signIn();
          
          if (googleUser == null) {
            _lastError = 'Google sign-in was cancelled';
            print('❌ [GOOGLE LOGIN] Google sign-in was cancelled by user');
            return false;
          }

          print('✅ [GOOGLE LOGIN] Google authentication successful (mobile)');
          print('   Email: ${googleUser.email}');
          print('   Name: ${googleUser.displayName}');

          // Get the authentication credentials
          final googleAuth = await googleUser.authentication;
          
          // Create a new credential using the tokens
          final credential = fb.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          // Sign in to Firebase with the credential
          print('🔐 [GOOGLE LOGIN] Authenticating with Firebase...');
          final userCredential = await _auth.signInWithCredential(credential);
          final user = userCredential.user;

          if (user == null) {
            _lastError = 'Firebase authentication failed';
            print('❌ [GOOGLE LOGIN] Firebase authentication failed: user is null');
            return false;
          }

          print('✅ [GOOGLE LOGIN] Firebase authentication successful');
          print('   UID: ${user.uid}');
          print('   Email: ${user.email}');

          // CRITICAL: Check if user is registered (exists in Firestore)
          print('🔍 [GOOGLE LOGIN] Checking if user is registered in Firestore...');
          final isRegistered = await isGoogleUserRegistered(user.uid);
          
          print('📊 [GOOGLE LOGIN] Registration check result: $isRegistered');
          
          if (!isRegistered) {
            // User is authenticated with Google but NOT registered in the app
            print('❌ [GOOGLE LOGIN] User NOT registered in Firestore!');
            print('   UID: ${user.uid}');
            print('   User must register first before logging in');
            print('🔐 [GOOGLE LOGIN] Signing out user...');
            
            try {
              await _auth.signOut();
              await _googleSignIn.signOut();
              print('✅ [GOOGLE LOGIN] Signed out unregistered Google user');
            } catch (e) {
              print('⚠️ [GOOGLE LOGIN] Error signing out: $e');
            }
            
            _lastError = 'This Google account is not registered. Please register first.';
            return false;
          }

          print('✅ [GOOGLE LOGIN] User IS registered in Firestore');
          print('✅ [GOOGLE LOGIN] Google login successful!');
          return true;
        } catch (e) {
          _lastError = 'Google sign-in error: $e';
          print('❌ [GOOGLE LOGIN] Native Google sign-in error: $e');
          return false;
        }
      }
    } on fb.FirebaseAuthException catch (e) {
      _lastError = _getFirebaseErrorMessage(e.code);
      print('❌ [GOOGLE LOGIN] Firebase Auth error: ${e.code} - ${e.message}');
      // Ensure user is signed out after auth failure
      try {
        await _auth.signOut();
        await _googleSignIn.signOut();
      } catch (_) {}
      return false;
    } catch (e) {
      _lastError = 'Google sign-in error: $e';
      print('❌ [GOOGLE LOGIN] Unexpected error: $e');
      // Ensure user is signed out after any error
      try {
        await _auth.signOut();
        await _googleSignIn.signOut();
      } catch (_) {}
      return false;
    }
  }

  /// ============================================
  /// GOOGLE AUTHENTICATION - REGISTER
  /// ============================================
  /// Register with Google - Creates new user account and Firestore profile
  /// Step 1: Authenticate with Google
  /// Step 2: Create user document in Firestore
  /// Step 3: Verify document was created
  Future<bool> registerWithGoogle() async {
    try {
      _lastError = null;

      if (!await _ensureFirebaseInitialized()) {
        _lastError = 'Firebase is not initialized';
        print('❌ Firebase not initialized for Google registration');
        return false;
      }

      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        print('📝 [GOOGLE REGISTER] Starting Google authentication via popup...');
        final userCredential = await _auth.signInWithPopup(provider);
        final user = userCredential.user;

        if (user == null) {
          _lastError = 'Google sign-in failed';
          print('❌ [GOOGLE REGISTER] Google sign-in failed: user is null');
          return false;
        }

        print('✅ [GOOGLE REGISTER] Google authentication successful');
        print('   UID: ${user.uid}');
        print('   Email: ${user.email}');
        print('   Name: ${user.displayName}');

        // Check if user already exists in Firestore
        print('🔍 [GOOGLE REGISTER] Checking if user already registered in Firestore...');
        final alreadyExists = await isGoogleUserRegistered(user.uid);
        
        if (alreadyExists) {
          print('ℹ️ [GOOGLE REGISTER] User already registered in Firestore');
          _lastError = 'This Google account is already registered. Please log in instead.';
          
          // Sign out since this is not a new registration
          try {
            await _auth.signOut();
            print('✅ [GOOGLE REGISTER] Signed out duplicate account');
          } catch (e) {
            print('⚠️ [GOOGLE REGISTER] Error signing out duplicate: $e');
          }
          return false;
        }

        print('📝 [GOOGLE REGISTER] Creating new user profile in Firestore...');
        final fullName = user.displayName ?? 'User';
        final email = user.email ?? '';
        final photoUrl = user.photoURL ?? '';

        // Create user profile in Firestore
        final profileCreated = await _firebaseUserService.createUserProfile(
          uid: user.uid,
          fullName: fullName,
          email: email,
          authProvider: 'google',
          photoURL: photoUrl,
        );

        if (!profileCreated) {
          _lastError = 'Failed to create user profile. Please try again.';
          print('❌ [GOOGLE REGISTER] FirebaseUserService.createUserProfile() returned false');
          
          // Sign out since we couldn't create the profile
          try {
            await _auth.signOut();
            print('✅ [GOOGLE REGISTER] Signed out user due to profile creation failure');
          } catch (e) {
            print('⚠️ [GOOGLE REGISTER] Error signing out after failed profile creation: $e');
          }
          return false;
        }

        // Verify the document was actually created in Firestore
        print('🔍 [GOOGLE REGISTER] Verifying Firestore document was created...');
        await Future.delayed(const Duration(milliseconds: 500)); // Give Firestore time to persist
        final verified = await isGoogleUserRegistered(user.uid);
        
        if (!verified) {
          _lastError = 'Profile creation verification failed. Please try again.';
          print('❌ [GOOGLE REGISTER] Firestore document verification FAILED');
          print('   UID: ${user.uid}');
          print('   Document should exist at: users/${user.uid}');
          
          // Sign out since verification failed
          try {
            await _auth.signOut();
          } catch (e) {
            print('⚠️ Error signing out after verification failure: $e');
          }
          return false;
        }

        print('✅ [GOOGLE REGISTER] Firestore document verified successfully!');
        print('✅ [GOOGLE REGISTER] Google registration complete!');
        print('   User can now login and complete profile setup');
        _lastError = null;
        return true;
      } else {
        // Mobile/Android implementation using google_sign_in package
        print('📝 [GOOGLE REGISTER] Starting Google authentication via native flow (mobile)...');
        
        try {
          // Attempt to sign in with Google
          final googleUser = await _googleSignIn.signIn();
          
          if (googleUser == null) {
            _lastError = 'Google sign-in was cancelled';
            print('❌ [GOOGLE REGISTER] Google sign-in was cancelled by user');
            return false;
          }

          print('✅ [GOOGLE REGISTER] Google authentication successful (mobile)');
          print('   Email: ${googleUser.email}');
          print('   Name: ${googleUser.displayName}');

          // Get the authentication credentials
          final googleAuth = await googleUser.authentication;
          
          // Create a new credential using the tokens
          final credential = fb.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          // Sign in to Firebase with the credential
          print('🔐 [GOOGLE REGISTER] Authenticating with Firebase...');
          final userCredential = await _auth.signInWithCredential(credential);
          final user = userCredential.user;

          if (user == null) {
            _lastError = 'Firebase authentication failed';
            print('❌ [GOOGLE REGISTER] Firebase authentication failed: user is null');
            return false;
          }

          print('✅ [GOOGLE REGISTER] Firebase authentication successful');
          print('   UID: ${user.uid}');
          print('   Email: ${user.email}');

          // Check if user already exists in Firestore
          print('🔍 [GOOGLE REGISTER] Checking if user already registered in Firestore...');
          final alreadyExists = await isGoogleUserRegistered(user.uid);
          
          if (alreadyExists) {
            print('ℹ️ [GOOGLE REGISTER] User already registered in Firestore');
            _lastError = 'This Google account is already registered. Please log in instead.';
            
            // Sign out since this is not a new registration
            try {
              await _auth.signOut();
              await _googleSignIn.signOut();
              print('✅ [GOOGLE REGISTER] Signed out duplicate account');
            } catch (e) {
              print('⚠️ [GOOGLE REGISTER] Error signing out duplicate: $e');
            }
            return false;
          }

          print('📝 [GOOGLE REGISTER] Creating new user profile in Firestore...');
          final fullName = user.displayName ?? 'User';
          final email = user.email ?? '';
          final photoUrl = user.photoURL ?? '';

          // Create user profile in Firestore
          final profileCreated = await _firebaseUserService.createUserProfile(
            uid: user.uid,
            fullName: fullName,
            email: email,
            authProvider: 'google',
            photoURL: photoUrl,
          );

          if (!profileCreated) {
            _lastError = 'Failed to create user profile. Please try again.';
            print('❌ [GOOGLE REGISTER] FirebaseUserService.createUserProfile() returned false');
            
            // Sign out since we couldn't create the profile
            try {
              await _auth.signOut();
              await _googleSignIn.signOut();
              print('✅ [GOOGLE REGISTER] Signed out user due to profile creation failure');
            } catch (e) {
              print('⚠️ [GOOGLE REGISTER] Error signing out after failed profile creation: $e');
            }
            return false;
          }

          // Verify the document was actually created in Firestore
          print('🔍 [GOOGLE REGISTER] Verifying Firestore document was created...');
          await Future.delayed(const Duration(milliseconds: 500)); // Give Firestore time to persist
          final verified = await isGoogleUserRegistered(user.uid);
          
          if (!verified) {
            _lastError = 'Profile creation verification failed. Please try again.';
            print('❌ [GOOGLE REGISTER] Firestore document verification FAILED');
            print('   UID: ${user.uid}');
            print('   Document should exist at: users/${user.uid}');
            
            // Sign out since verification failed
            try {
              await _auth.signOut();
              await _googleSignIn.signOut();
            } catch (e) {
              print('⚠️ Error signing out after verification failure: $e');
            }
            return false;
          }

          print('✅ [GOOGLE REGISTER] Firestore document verified successfully!');
          print('✅ [GOOGLE REGISTER] Google registration complete!');
          _lastError = null;
          return true;
        } catch (e) {
          _lastError = 'Google registration error: $e';
          print('❌ [GOOGLE REGISTER] Native Google registration error: $e');
          return false;
        }
      }
    } on fb.FirebaseAuthException catch (e) {
      _lastError = _getFirebaseErrorMessage(e.code);
      print('❌ [GOOGLE REGISTER] Firebase Auth error: ${e.code} - ${e.message}');
      // Clean up: sign out if registration failed
      try {
        await _auth.signOut();
        await _googleSignIn.signOut();
      } catch (_) {}
      return false;
    } catch (e) {
      _lastError = 'Google registration error: $e';
      print('❌ [GOOGLE REGISTER] Unexpected error: $e');
      
      // Clean up: sign out if registration failed
      try {
        await _auth.signOut();
        await _googleSignIn.signOut();
      } catch (_) {}
      return false;
    }
  }

  /// ============================================
  /// HELPER METHOD - Check if Google user is registered
  /// ============================================
  /// Verifies that a Google user exists in Firestore users/{uid} collection
  /// This is used by both registerWithGoogle() and signInWithGoogle()
  /// Returns true ONLY if: user document exists AND has required fields
  /// Returns false for: document not found, missing fields, errors, permission issues
  /// SECURITY: Defaults to false - denies access unless explicitly verified
  Future<bool> isGoogleUserRegistered(String uid) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        print('⚠️ [VERIFY] Firebase not initialized, cannot verify registration');
        return false; // Default to NOT registered if we can't check
      }

      if (uid.isEmpty) {
        print('⚠️ [VERIFY] UID is empty, cannot verify registration');
        return false;
      }

      print('🔍 [VERIFY] Checking Firestore document: users/$uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (!doc.exists) {
        print('❌ [VERIFY] Document NOT found in Firestore');
        print('   Expected path: users/$uid');
        return false;
      }

      // Document exists - verify it has required fields for a valid registered user
      final data = doc.data();
      if (data == null) {
        print('❌ [VERIFY] Document has no data (is empty)');
        return false;
      }

      // Check for required fields
      final hasUid = data.containsKey('uid') && data['uid'] != null;
      final hasEmail = data.containsKey('email') && data['email'] != null;
      final hasAuthProvider = data.containsKey('authProvider') && data['authProvider'] != null;
      
      if (!hasUid || !hasEmail) {
        print('❌ [VERIFY] Document missing required fields!');
        print('   Has uid: $hasUid');
        print('   Has email: $hasEmail');
        print('   Has authProvider: $hasAuthProvider');
        return false;
      }

      print('✅ [VERIFY] User IS registered with all required fields');
      print('   Email: ${data['email']}');
      print('   Auth Provider: ${data['authProvider']}');
      print('   Profile Complete: ${data['isProfileCompleted'] ?? false}');
      return true;
    } on FirebaseException catch (e) {
      // Firestore error - log it but default to NOT registered for security
      print('❌ [VERIFY] Firestore error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      // Any other error - default to NOT registered for security
      print('❌ [VERIFY] Unexpected error during verification: $e');
      return false;
    }
  }

  /// ============================================
  /// ROUTE RESOLUTION - CENTRALIZED POST-AUTH LOGIC
  /// ============================================
  /// Determines the next route after successful authentication
  /// Checks Firestore for user profile and completion status
  /// 
  /// Returns:
  /// - "fitnessProfileSetup" if profile doesn't exist or isProfileCompleted is false
  /// - "dashboard" if profile exists and isProfileCompleted is true
  /// 
  /// Creates a minimal user document if it doesn't exist
  Future<String> resolveNextRouteAfterAuth(fb.User firebaseUser) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        print('❌ [ROUTE RESOLUTION] Firebase not initialized');
        return 'fitnessProfileSetup'; // Fallback to profile setup
      }

      final uid = firebaseUser.uid;
      print('🔍 [ROUTE RESOLUTION] Checking route for UID: $uid');
      print('   Email: ${firebaseUser.email}');

      // Fetch user document from Firestore
      final userDocSnapshot = await _firestore.collection('users').doc(uid).get();

      if (!userDocSnapshot.exists) {
        // Document doesn't exist - create minimal user document
        print('📝 [ROUTE RESOLUTION] User document NOT found. Creating minimal profile...');
        
        final now = Timestamp.now();
        final minimalProfile = {
          'uid': uid,
          'email': firebaseUser.email ?? '',
          'displayName': firebaseUser.displayName ?? '',
          'photoURL': firebaseUser.photoURL ?? '',
          'authProvider': 'email', // Default to email, will be overridden if Google
          'isProfileCompleted': false,
          'createdAt': now,
          'updatedAt': now,
        };

        try {
          await _firestore.collection('users').doc(uid).set(minimalProfile);
          print('✅ [ROUTE RESOLUTION] Minimal profile created successfully');
        } catch (e) {
          print('⚠️ [ROUTE RESOLUTION] Warning: Failed to create minimal profile: $e');
          // Continue anyway - will show profile setup
        }

        print('🔄 [ROUTE RESOLUTION] Routing to: fitnessProfileSetup (new user)');
        return 'fitnessProfileSetup';
      }

      // Document exists - check isProfileCompleted flag
      final userData = userDocSnapshot.data();
      final isProfileCompleted = userData?['isProfileCompleted'] ?? false;

      print('✅ [ROUTE RESOLUTION] User document found');
      print('   isProfileCompleted: $isProfileCompleted');

      if (!isProfileCompleted) {
        print('🔄 [ROUTE RESOLUTION] Routing to: fitnessProfileSetup (incomplete profile)');
        return 'fitnessProfileSetup';
      }

      print('🔄 [ROUTE RESOLUTION] Routing to: dashboard (completed profile)');
      return 'dashboard';
    } catch (e) {
      print('❌ [ROUTE RESOLUTION] Error resolving route: $e');
      // Default to profile setup on error
      return 'fitnessProfileSetup';
    }
  }

  /// Firebase login with email and password
  Future<bool> login(String email, String password) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        _lastError = 'Firebase is not initialized. Please restart the app.';
        print('❌ Firebase initialization failed during login');
        return false;
      }

      print('🔐 Attempting login with email: $email');
      print('📱 Firebase app initialized: ${fb_core.Firebase.apps.isNotEmpty}');
      _lastError = null;
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print('✅ Login successful, user: ${userCredential.user?.email}');
      return true;
    } on fb.FirebaseAuthException catch (e) {
      _lastError = _getFirebaseErrorMessage(e.code);
      print('❌ Login error: ${e.code} - ${e.message}');
      print('📝 User message: $_lastError');
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      print('❌ Unexpected error during login: $e');
      return false;
    }
  }

  /// Firebase register with email and password
  Future<bool> register(
    String name,
    String email,
    String password,
    String confirmPassword,
  ) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        _lastError = 'Firebase is not initialized. Please restart the app.';
        print('❌ Firebase initialization failed during registration');
        return false;
      }

      // Validate inputs
      if (email.isEmpty || password.isEmpty || name.isEmpty) {
        _lastError = 'Email, password, and name cannot be empty';
        print('❌ $_lastError');
        return false;
      }

      if (password != confirmPassword) {
        _lastError = 'Passwords do not match';
        print('❌ $_lastError');
        return false;
      }

      if (password.length < 8) {
        _lastError = 'Password must be at least 8 characters';
        print('❌ $_lastError');
        return false;
      }

      print('📝 Attempting registration with email: $email');
      // Create user account in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final userId = userCredential.user!.uid;
      print('✅ Registration successful, userId: $userId');

      await _ensureUserProfile(userId, name, email.trim());
      _lastError = null;
      return true;
    } on fb.FirebaseAuthException catch (e) {
      _lastError = _getFirebaseErrorMessage(e.code);
      print('❌ Registration error: ${e.code} - ${e.message}');
      print('📝 User message: $_lastError');
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      print('❌ Unexpected error during registration: $e');
      return false;
    }
  }

  /// Convert Firebase error codes to user-friendly messages
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
        return 'Incorrect password. Please try again';
      case 'invalid-email':
        return 'Invalid email address format';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled';
      case 'email-already-in-use':
        return 'This email is linked to Google. Please use "Sign in with Google';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters';
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return 'Authentication error: $code';
    }
  }

  /// Firebase logout
  Future<void> logout() async {
    try {
      if (fb_core.Firebase.apps.isEmpty) {
        return;
      }

      await _auth.signOut();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Get current user data from Firestore
  Future<User?> getCurrentUserData() async {
    try {
      if (fb_core.Firebase.apps.isEmpty) {
        return null;
      }

      final fbUser = _auth.currentUser;
      if (fbUser == null) return null;

      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return User(
        id: fbUser.uid,
        name: data['fullName'] ?? data['name'] ?? 'User',
        email: fbUser.email ?? '',
        height: (data['height'] ?? 170).toDouble(),
        weight: (data['weight'] ?? 65).toDouble(),
        gender: data['gender'] ?? 'Not specified',
        age: data['age'] ?? 0,
        dateOfBirth: data['dateOfBirth'] != null
            ? (data['dateOfBirth'] as Timestamp).toDate()
            : DateTime.now(),
            photoURL: data['photoURL'] ?? '',
      );
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  /// Update user profile in Firestore
  Future<bool> updateProfile(User updatedUser) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        return false;
      }

      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      await _firestore.collection('users').doc(userId).update({
        'name': updatedUser.name,
        'height': updatedUser.height,
        'weight': updatedUser.weight,
        'gender': updatedUser.gender,
        'age': updatedUser.age,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  /// Reset password - sends OTP via email
  Future<String?> resetPassword(String email) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        _lastError = 'Firebase is not initialized. Please restart the app.';
        print('❌ Firebase initialization failed during password reset');
        return null;
      }

      print('🔐 Processing password reset for: $email');

      // Check if email exists in Firebase Auth
      var emailExistsInAuth = false;
      try {
        final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
        emailExistsInAuth = methods.isNotEmpty;
        print('✅ Email found in Firebase Auth: $email');
      } on fb.FirebaseAuthException catch (e) {
        print('⚠️  Email not found in Firebase Auth: ${e.code}');
        emailExistsInAuth = false;
      } catch (e) {
        print('⚠️  Error checking Firebase Auth: $e');
        emailExistsInAuth = false;
      }

      // Also check if email exists in Firestore users collection
      var emailExistsInFirestore = false;
      try {
        final snapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim().toLowerCase())
            .limit(1)
            .get();
        emailExistsInFirestore = snapshot.docs.isNotEmpty;
        print('Firestore check: ${emailExistsInFirestore ? '✅ Found' : '❌ Not found'}');
      } catch (e) {
        print('⚠️  Error checking Firestore: $e');
      }

      // Provide helpful error message
      if (!emailExistsInAuth && !emailExistsInFirestore) {
        _lastError = 'No account found with this email address. Please register first.';
        print('❌ Email not found in both Firebase Auth and Firestore');
        return null;
      }

      

      // Generate 6-digit OTP
      final otp = _generateOTP();
      print('🔑 Generated OTP: $otp');
      
      // Store OTP in Firestore
      print('💾 Storing OTP in Firestore...');
      await _firestore.collection('passwordResets').doc(email.trim().toLowerCase()).set({
        'otp': otp,
        'email': email.trim().toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 15))),
      });
      print('✅ OTP stored in Firestore');

      // Get user name if possible (don't fail if read fails)
      var userName = 'User';
      try {
        final userId = _auth.currentUser?.uid;
        if (userId != null && userId.isNotEmpty) {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            userName = userDoc.data()?['name'] ?? 'User';
          }
        }
      } catch (e) {
        print('⚠️ Could not fetch user name (non-critical): $e');
        // Continue even if user read fails
      }

      // Send OTP via EmailJS
      print('📧 Sending OTP email to: $email');
      final emailService = EmailService();
      final emailSent = await emailService.sendOTPEmail(
        userEmail: email.trim(),
        otp: otp,
        userName: userName,
      );

      if (!emailSent) {
        _lastError = emailService.lastError ?? 'Failed to send OTP email';
        print('❌ Failed to send OTP email: $_lastError');
        return null;
      }

      print('✅ OTP email sent successfully to $email');
      return otp; // Return OTP for immediate testing (remove in production)
    } catch (e) {
      _lastError = 'Error sending password reset: $e';
      print('❌ Error: $_lastError');
      return null;
    }
  }

  /// Verify OTP and send password reset email
  Future<bool> verifyOTPAndSendReset(String email, String otp) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        return false;
      }

      final doc = await _firestore.collection('passwordResets').doc(email.trim().toLowerCase()).get();
      if (!doc.exists) {
        _lastError = 'OTP not found or expired';
        return false;
      }

      final data = doc.data()!;
      final storedOTP = data['otp'];
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        _lastError = 'OTP has expired';
        await doc.reference.delete();
        return false;
      }

      if (storedOTP != otp) {
        _lastError = 'Invalid OTP';
        return false;
      }

      // Send password reset email
      // ✅ FIXED - skip reset email if no Auth account yet
try {
  final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
  if (methods.isNotEmpty) {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
} catch (e) {
  print('⚠️ No Auth account yet, skipping reset email: $e');
}

// Delete the OTP document
await doc.reference.delete();
_lastError = null;
return true;

      
    } catch (e) {
      _lastError = 'Error verifying OTP: $e';
      return false;
    }
  }

/// Update password directly after OTP verification
Future<bool> updatePasswordAfterOTP(String email, String newPassword) async {
  try {
    if (!await _ensureFirebaseInitialized()) return false;

    if (newPassword.length < 8) {
      _lastError = 'Password must be at least 8 characters';
      return false;
    }

    List<String> methods = [];
    try {
      methods = await _auth.fetchSignInMethodsForEmail(email.trim());
    } catch (_) {}

    if (methods.isEmpty) {
      print('🔧 No Auth account found — creating one for: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: newPassword,
      );

      final newUid = userCredential.user!.uid;

      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && snapshot.docs.first.id != newUid) {
        await _firestore.collection('users').doc(newUid).set(snapshot.docs.first.data());
        await snapshot.docs.first.reference.delete();
        print('✅ Firestore doc migrated to new UID: $newUid');
      }
      print('✅ Auth account created with new password');
    } else {
      await _auth.sendPasswordResetEmail(email: email.trim());
      print('✅ Password reset email sent to: $email');
    }

    _lastError = null;
    return true;
  } on fb.FirebaseAuthException catch (e) {
    _lastError = _getFirebaseErrorMessage(e.code);
    return false;
  } catch (e) {
    _lastError = 'Error updating password: $e';
    return false;
  }
}


  /// Update password with OTP verification (direct Firebase update)
  Future<bool> updatePasswordWithOTP(String email, String otp, String newPassword) async {
    try {
      if (!await _ensureFirebaseInitialized()) {
        return false;
      }

      // First verify the OTP
      final doc = await _firestore.collection('passwordResets').doc(email.trim().toLowerCase()).get();
      if (!doc.exists) {
        _lastError = 'OTP not found or expired';
        return false;
      }

      final data = doc.data()!;
      final storedOTP = data['otp'];
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        _lastError = 'OTP has expired';
        await doc.reference.delete();
        return false;
      }

      if (storedOTP != otp) {
        _lastError = 'Invalid OTP';
        return false;
      }

      // Validate password
      if (newPassword.length < 8) {
        _lastError = 'Password must be at least 8 characters';
        return false;
      }

      // Send password reset email and delete OTP
      // User will need to complete the password reset via email link
      // ✅ FIXED - skip reset email if no Auth account yet
try {
  final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
  if (methods.isNotEmpty) {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
} catch (e) {
  print('⚠️ No Auth account yet, skipping reset email: $e');
}

// Delete the OTP document
await doc.reference.delete();
_lastError = null;
return true;
      
    } on fb.FirebaseAuthException catch (e) {
      _lastError = _getFirebaseErrorMessage(e.code);
      return false;
    } catch (e) {
      _lastError = 'Error updating password: $e';
      return false;
    }
  }

  /// Generate a 6-digit OTP
  String _generateOTP() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  Future<void> _ensureUserProfile(String userId, String name, String email) async {
    try {
      // Check if profile already exists
      final exists = await _firebaseUserService.userProfileExists(userId);
      if (exists) {
        print('ℹ️ User profile already exists');
        return;
      }

      // Create new user profile using FirebaseUserService
      print('💾 Creating user profile for email registration...');
      await _firebaseUserService.createUserProfile(
        uid: userId,
        fullName: name,
        email: email.trim(),
        authProvider: 'email',
      );
      print('✅ User profile created successfully');
    } catch (e) {
      print('⚠️ Warning: Failed to create user profile: $e');
    }
  }

  Future<bool> _ensureFirebaseInitialized() async {
    if (fb_core.Firebase.apps.isNotEmpty) {
      print('✅ Firebase already initialized');
      return true;
    }

    try {
      print('⏳ Initializing Firebase...');
      await fb_core.Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized successfully');
      return true;
    } catch (e) {
      _lastError = 'Firebase initialization failed: $e';
      print('❌ Firebase initialization error: $_lastError');
      return false;
    }
  }

  /// Sign in user directly after OTP verification (no password needed)
/// Used for forgot password flow — logs in via custom token approach
/// For Google-only accounts, we sign in using a temporary password link
Future<bool> loginAfterOTPVerification(String email) async {
  try {
    if (!await _ensureFirebaseInitialized()) {
      _lastError = 'Firebase is not initialized';
      return false;
    }

    // Check what sign-in methods this email has
    List<String> methods = [];
    try {
      methods = await _auth.fetchSignInMethodsForEmail(email.trim());
    } catch (e) {
      print('⚠️ Could not fetch sign-in methods: $e');
    }

    print('🔍 Sign-in methods for $email: $methods');

    if (methods.contains('google.com')) {
      // Google account — cannot sign in silently without user interaction
      // We mark OTP as verified so AuthGate can handle Google sign-in prompt
      _lastError = 'google_account'; // Special signal to UI
      print('ℹ️ Account uses Google — UI should prompt Google sign-in');
      return false;
    }

    if (methods.contains('password')) {
      // Email/password account — send reset email and notify user
      await _auth.sendPasswordResetEmail(email: email.trim());
      _lastError = 'password_reset_sent'; // Special signal to UI
      print('📧 Password reset email sent to $email');
      return false;
    }

    // No auth account exists — create one with a temporary password,
    // sign them in, then they can set a real password from profile settings
    print('🔧 No auth account found — creating temporary account for: $email');
    final tempPassword = 'Temp_${DateTime.now().millisecondsSinceEpoch}';
    
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: tempPassword,
    );

    final newUid = userCredential.user!.uid;

    // Migrate Firestore doc if needed
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty && snapshot.docs.first.id != newUid) {
      await _firestore.collection('users').doc(newUid).set(snapshot.docs.first.data());
      await snapshot.docs.first.reference.delete();
      print('✅ Firestore doc migrated to new UID: $newUid');
    }

    // Send reset email so user can set a real password later
    await _auth.sendPasswordResetEmail(email: email.trim());
    print('✅ Signed in and sent password setup email to $email');

    _lastError = null;
    return true;
  } on fb.FirebaseAuthException catch (e) {
    _lastError = _getFirebaseErrorMessage(e.code);
    return false;
  } catch (e) {
    _lastError = 'Login error: $e';
    return false;
  }
}
}
