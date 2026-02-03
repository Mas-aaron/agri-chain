# Firebase → Supabase Migration Plan
**Project**: agri-chain  
**Date Created**: 2026-02-03  
**Estimated Duration**: 1-2 hours

---

## Phase 1: Supabase Project Setup (Prerequisites)

- [ ] **Create Supabase Account**
  - Go to [supabase.com](https://supabase.com)
  - Sign up if you don't have an account
  - Create a new project
  
- [ ] **Get Supabase Credentials**
  - Project URL: `https://[project-id].supabase.co`
  - API Key (anon): Available in Settings > API
  - Store these securely (add to environment variables or `.env` file)

- [ ] **Upload ML Model Files to Supabase Storage**
  - Create a bucket named `models`
  - Upload `maize_disease.tflite`
  - Upload `labels.txt`
  - Make bucket public or set up signed URLs
  - Note the public URLs:
    - `https://[project-id].supabase.co/storage/v1/object/public/models/maize_disease.tflite`
    - `https://[project-id].supabase.co/storage/v1/object/public/models/labels.txt`

---

## Phase 2: Update Dependencies

- [ ] **Update pubspec.yaml**
  - Remove: `firebase_core: ^4.3.0`
  - Remove: `firebase_storage: ^13.0.5`
  - Add: `supabase_flutter: ^2.3.0` (latest stable)
  - Run: `flutter pub get`

- [ ] **Remove Firebase plugin registrations** (auto-generated)
  - These will be regenerated after `flutter pub get`

---

## Phase 3: Code Changes

### 3.1 Update `lib/main.dart`

- [ ] Replace Firebase initialization with Supabase:
  ```dart
  // OLD:
  await Firebase.initializeApp();
  
  // NEW:
  await Supabase.initialize(
    url: 'https://[project-id].supabase.co',
    anonKey: '[your-anon-key]',
  );
  ```

- [ ] Add import:
  ```dart
  import 'package:supabase_flutter/supabase_flutter.dart';
  ```

- [ ] Remove import:
  ```dart
  import 'package:firebase_core/firebase_core.dart';
  ```

### 3.2 Update `lib/services/firebase_model_downloader.dart`

- [ ] Rename file (optional): `supabase_model_downloader.dart`

- [ ] Replace the baseUrl:
  ```dart
  // OLD:
  static const String baseUrl = 'https://agri-chain-models.web.app/models';
  
  // NEW:
  static const String baseUrl = 'https://[project-id].supabase.co/storage/v1/object/public/models';
  ```

- [ ] No other changes needed (HTTP download logic remains the same)

### 3.3 Update imports in dependent files

- [ ] Search for any imports of `firebase_model_downloader.dart`
- [ ] Update file paths if renamed:
  ```dart
  // If renamed to supabase_model_downloader.dart
  import 'package:agri_chain/services/supabase_model_downloader.dart';
  ```

---

## Phase 4: Configuration & Environment Setup

- [ ] **Create `.env` file** (optional but recommended):
  ```
  SUPABASE_URL=https://[project-id].supabase.co
  SUPABASE_ANON_KEY=[your-anon-key]
  ```

- [ ] **Create `lib/config/supabase_config.dart`** (best practice):
  ```dart
  class SupabaseConfig {
    static const String url = 'https://[project-id].supabase.co';
    static const String anonKey = '[your-anon-key]';
  }
  ```

- [ ] **Update main.dart to use config**:
  ```dart
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  ```

---

## Phase 5: Update Build Files & Configs

- [ ] **Remove Firestore rules**
  - Delete or archive: `firestore.rules`

- [ ] **Update Firestore config** (if kept for reference)
  - Delete or archive: `firestore.indexes.json`

- [ ] **Update Python deployment script** (`upload.py`)
  - Replace Firebase Hosting references with Supabase Storage commands
  - Update deployment documentation

- [ ] **Update Android build.gradle** (if Firebase minSdk requirement was set)
  - Current minSdk in app: `23` (required for Firebase Storage)
  - Can keep as is or adjust if desired (Supabase has similar requirements)

- [ ] **Update iOS (if applicable)**
  - Remove Firebase from CocoaPods
  - Run: `cd ios && pod deintegrate && pod install`

---

## Phase 6: Testing

- [ ] **Test app initialization**
  - Run: `flutter clean && flutter pub get && flutter run`
  - Verify no Firebase errors in logs

- [ ] **Test model download**
  - Launch app on emulator/device
  - Navigate to scan screen
  - Verify models download from Supabase correctly
  - Check in logs for successful download URLs

- [ ] **Test offline functionality**
  - Kill internet connection
  - Verify app falls back to bundled assets

- [ ] **Test on both platforms**
  - [ ] Android
  - [ ] iOS (if applicable)
  - [ ] Web (if applicable)

- [ ] **Verify SharedPreferences still works**
  - Scan with a field, verify data persists
  - App restart, verify data is still there

---

## Phase 7: Database Setup (Optional - For Future Features)

If you plan to use Supabase's PostgreSQL database:

- [ ] **Create tables** (if needed):
  - `fields` - store field data
  - `scans` - store scan history
  - `alerts` - store disease alerts

- [ ] **Set up Row Level Security (RLS)** for security

- [ ] **Create Supabase client service** for database operations

- [ ] **Migrate from SharedPreferences to Supabase DB** (future phase)

---

## Phase 8: Cleanup & Documentation

- [ ] **Remove Firebase files from project**
  - Delete: `firebase_deploy/` folder (backup first if needed)
  - Delete: `firestore.rules`
  - Delete: `firestore.indexes.json`

- [ ] **Update README.md**
  - Update deployment instructions
  - Add Supabase setup steps for developers

- [ ] **Update documentation files**
  - Update any deployment guides
  - Update SETUP.md if exists

- [ ] **Commit changes to git**
  ```bash
  git checkout -b firebase-to-supabase-migration
  git add .
  git commit -m "Migrate from Firebase to Supabase for model hosting and storage"
  git push origin firebase-to-supabase-migration
  ```

---

## Phase 9: Deployment

- [ ] **Build release APK/IPA**
  - Android: `flutter build apk --release`
  - iOS: `flutter build ios --release`

- [ ] **Test release builds** on physical devices

- [ ] **Deploy to app stores** (if applicable)

- [ ] **Monitor logs** for any issues post-deployment

---

## Rollback Plan (If Issues Occur)

- [ ] Keep Firebase credentials and setup intact for 1-2 weeks
- [ ] If critical issues found:
  - Switch model URL back to Firebase Hosting
  - Rollback code to previous commit
  - Investigate and retry

---

## File Checklist

### Files to Modify:
- [x] `pubspec.yaml` - Dependencies
- [ ] `lib/main.dart` - Initialization
- [ ] `lib/services/firebase_model_downloader.dart` - Model URL
- [ ] `upload.py` - Deployment script
- [ ] `README.md` - Documentation
- [ ] `BlockChainModule/PRODUCTION_NOTES.md` - Deployment notes

### Files to Remove/Archive:
- [ ] `firebase_deploy/` folder
- [ ] `firestore.rules`
- [ ] `firestore.indexes.json`

### New Files to Create (Optional):
- [ ] `lib/config/supabase_config.dart`
- [ ] `.env` file (for credentials)

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Models not downloading | Verify Supabase bucket is public or use signed URLs |
| CORS errors | Enable CORS in Supabase project settings |
| App crashes on init | Check Supabase URL and anon key are correct |
| Build fails | Run `flutter clean && flutter pub get` |
| iOS compilation fails | Run `cd ios && pod update` |
| Models download slow | Verify Supabase region is optimal; consider CDN |

---

## Next Steps

1. **Immediate**: Set up Supabase project and get credentials
2. **Short-term**: Update code (Phase 3-4)
3. **Testing**: Run full test suite (Phase 6)
4. **Deploy**: Release to production (Phase 9)

---

## Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Supabase Storage Docs](https://supabase.com/docs/guides/storage)
- [Flutter Best Practices](https://flutter.dev/docs/testing/best-practices)

---

**Status**: ⏳ Ready to start  
**Last Updated**: 2026-02-03
