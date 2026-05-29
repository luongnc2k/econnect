# FCM Setup — Kich hoat push notification cho EConnect

Toan bo code FCM da co san o client (`client/lib/features/notifications/push/`) va server (`server/push_notification_service.py`, `server/routes/notifications.py`). Tai lieu nay huong dan **cau hinh** de kich hoat luong end-to-end.

> TL;DR: tao Firebase project, tai 3 file credential, dien env cho client + server, test bang cach login va trigger 1 notification.

## 1. Firebase Console

Vao https://console.firebase.google.com/.

1. **Tao project** moi (vi du `econnect-prod`). Co the bat Google Analytics tuy chon.
2. **Add Android app**:
   - Package name: `com.example.client` (xem `client/android/app/build.gradle.kts:30`).
   - Tai `google-services.json`.
3. **Add iOS app**:
   - Bundle ID: `com.example.client` (xem `client/ios/Runner.xcodeproj/project.pbxproj`).
   - Tai `GoogleService-Info.plist`.
4. **Cloud Messaging → Apple app configuration → APNs Authentication Key**: upload `.p8` key tu Apple Developer (can Team ID + Key ID). Bat buoc neu muon push iOS production.
5. **Project Settings → Service Accounts → Generate new private key**: tai file JSON va luu lai (chua an toan, khong commit). Day la credential server dung de goi FCM v1 API.

## 2. Client — Android

- Dat `google-services.json` vao `client/android/app/google-services.json`. Plugin `com.google.gms.google-services` da apply co dieu kien o `client/android/app/build.gradle.kts:7-9`, nen chi can co file la build duoc.
- Permission `POST_NOTIFICATIONS` da co o `AndroidManifest.xml`.
- File da nam trong `.gitignore` — khong commit.

## 3. Client — iOS

- Mo `client/ios/Runner.xcworkspace` bang Xcode.
- Keo `GoogleService-Info.plist` vao group `Runner`, tick **Copy items if needed** va target **Runner**. Dat file thu cong vao filesystem khong du — Xcode build phase phai nhin thay.
- Tab **Signing & Capabilities** cua target `Runner`:
  - Bat **Push Notifications**.
  - Bat **Background Modes → Remote notifications** (`Info.plist:65` da co `remote-notification`, day chi them entitlement).
- File da nam trong `.gitignore` — khong commit.

## 4. Client — `--dart-define`

`NotificationsFcmOptions` doc 7 bien env qua `String.fromEnvironment` (`client/lib/features/notifications/push/notifications_fcm_options.dart:5-14`). Neu khong truyen, `supportsPushRuntime` tra `false` va toan bo FCM bypass im lang.

1. Copy `client/.env.fcm.example` → `client/.env.fcm` va dien gia tri.
2. Chay app bang script wrapper:
   ```bash
   cd client
   ./scripts/run-dev.sh                 # tren device mac dinh
   ./scripts/run-dev.sh -d <device-id>  # them tham so flutter run binh thuong
   ```

### Cach lay tung gia tri

| Bien | Lay tu | Vi du |
| --- | --- | --- |
| `FCM_API_KEY` | `google-services.json → client[0].api_key[0].current_key` (Android) hoac plist `API_KEY` (iOS) | `AIzaSy...` |
| `FCM_PROJECT_ID` | `project_info.project_id` | `econnect-prod` |
| `FCM_MESSAGING_SENDER_ID` | `project_info.project_number` | `1234567890` |
| `FCM_ANDROID_APP_ID` | `client[0].client_info.mobilesdk_app_id` | `1:1234567890:android:abc...` |
| `FCM_IOS_APP_ID` | plist `GOOGLE_APP_ID` | `1:1234567890:ios:def...` |
| `FCM_IOS_BUNDLE_ID` | plist `BUNDLE_ID` | `com.example.client` |
| `FCM_STORAGE_BUCKET` | `project_info.storage_bucket` (Android) hoac plist `STORAGE_BUCKET` | `econnect-prod.appspot.com` |

## 5. Server — Application Default Credentials (keyless)

Server chay tren Cloud Run dung **Application Default Credentials (ADC)** thay vi service account JSON key. Ly do: org policy `constraints/iam.disableServiceAccountKeyCreation` chan tao SA key (best practice security). ADC khong can key — Cloud Run runtime SA tu lay token qua metadata server.

Thu tu fallback trong `_firebase_credentials()` (`server/push_notification_service.py:55-86`):

1. `FCM_SERVICE_ACCOUNT_PATH` (legacy, neu set thi dung)
2. `FCM_SERVICE_ACCOUNT_JSON` (legacy)
3. **ADC** (mac dinh tren Cloud Run + local sau khi `gcloud auth application-default login`)

### Setup Cloud Run

```bash
# 1. Cap role gui FCM cho runtime SA cua Cloud Run
gcloud projects add-iam-policy-binding econnect-prod \
  --member="serviceAccount:econnect-server@econnect-prod.iam.gserviceaccount.com" \
  --role="roles/firebasecloudmessaging.admin"

# 2. Set project id cho firebase_admin biet target project
gcloud run services update econnect-server \
  --project=econnect-prod \
  --region=asia-southeast1 \
  --update-env-vars=FCM_PROJECT_ID=econnect-prod
```

(`GOOGLE_CLOUD_PROJECT` cung duoc Cloud Run auto-set, nhung dat them `FCM_PROJECT_ID` cho ro y do va de override.)

### Setup local dev

```bash
cd server
source venv/bin/activate
pip install -r requirements.txt        # bao dam firebase-admin co trong venv

# Login ADC bang tai khoan da co role FCM tren project
gcloud auth application-default login

# Smoke test
FCM_PROJECT_ID=econnect-prod python -c "
import push_notification_service as p
print('fcm_is_enabled() =', p.fcm_is_enabled())
"
# Expected: fcm_is_enabled() = True
```

Khi chay `uvicorn` o local, them vao `server/.env`:
```
FCM_PROJECT_ID=econnect-prod
```

## 6. Verification end-to-end

1. **Server**: chay `uvicorn main:app --reload` sau khi set `FCM_PROJECT_ID=econnect-prod` va da `gcloud auth application-default login`. Smoke check `fcm_is_enabled()` → `True`.
2. **Client token registration**:
   - Chay `./scripts/run-dev.sh`.
   - Login bang tai khoan test.
   - Kiem tra DB:
     ```sql
     SELECT id, user_id, platform, is_active, last_seen_at
     FROM push_device_tokens
     WHERE user_id = '<uid>'
     ORDER BY last_seen_at DESC;
     ```
     Phai co 1 row moi voi `is_active=true`.
3. **Push delivery**:
   - Trigger 1 notification, vi du tao class moi qua `POST /classes` (xem `server/routes/classes.py:408`).
   - App o foreground: console log tu listener `FirebaseMessaging.onMessage` (`notifications_push_service.dart:93`) phai in payload.
   - App o background hoac da kill: thay banner system tray; tap banner → deep-link dung (teacher → `/teacher/class-summary/<class_code>`, role khac → `AppRoutes.notifications`, logic tai `notifications_push_service.dart:172-180`).
4. **Token cleanup**: uninstall app → trigger lai notification → server log thay marker "registration-token-not-registered"; row tuong ung bi set `is_active=false` (`push_notification_service.py:194-202`).

## Troubleshooting

- **Client khong tao Firebase app**: kiem tra `--dart-define` da truyen dung (co the in `NotificationsFcmOptions.isConfigured` tu debugger). Neu sai 1 trong 4 bien bat buoc (`FCM_API_KEY`, `FCM_PROJECT_ID`, `FCM_MESSAGING_SENDER_ID`, va 1 trong `FCM_ANDROID_APP_ID`/`FCM_IOS_APP_ID`) thi `isConfigured` se `false`.
- **iOS khong nhan push**: kiem tra APNs key da upload Firebase, capability **Push Notifications** da bat trong Xcode, va testing tren real device (simulator iOS khong nhan FCM push truoc iOS 16).
- **Server gui nhung client khong nhan**: dam bao `push_device_tokens.is_active=true` va `last_seen_at` moi. Neu token cu, force re-register bang cach logout → login.
- **Server log "Khong gui duoc FCM cho user ..."**: xem ky error message — neu chua marker "unregistered" thi token tu dong bi deactivate (logic ben tren).
- **Local `fcm_is_enabled() = False`**:
  - `firebase_admin = None` → chua cai package: `pip install -r requirements.txt`.
  - `firebase_admin` co nhung van False → chua `gcloud auth application-default login`, hoac tai khoan local chua co role `roles/firebasecloudmessaging.admin` tren project.
- **Cloud Run khong gui duoc**: kiem tra `gcloud projects get-iam-policy econnect-prod --filter="bindings.members:econnect-server@*"` phai co `roles/firebasecloudmessaging.admin`.
