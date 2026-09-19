# Yadda Za a Gina .aab a GitHub (Cloud) — Babu Bukatar Flutter a Kwamfutarka

Wannan zip ɗin ya ƙunshi:
- `.github/workflows/build-aab.yml` — umarnin gina app ɗin (CI)
- `scripts/patch-android.sh` — script wanda ke ƙirƙiro android/ios kuma
  ya yi duk gyare-gyaren da README.md ta ambata, ta atomatik
- `.gitignore` — don kada asirin ka (keystore, passwords) su shiga repo

## Mataki 1 — Bude GitHub Account
1. Je zuwa https://github.com/join
2. Cika email, password, username, ka tabbatar (verify) email ɗinka

## Mataki 2 — Kirkiro Repository
1. Danna "+" a saman shafi > "New repository"
2. Sunan repo: misali `katsinasub-mobile-app`
3. Zaɓi **Private** (domin code ɗinka na sirri ne)
4. Danna "Create repository"

## Mataki 3 — Tura Fayiloli
1. A shafin repo ɗin da aka kirkiro, danna "uploading an existing file"
   (ko "Add file" > "Upload files")
2. Bude folder ɗin da ka fitar daga wannan zip a kwamfutarka
3. **MUHIMMI**: tabbata File Manager ɗinka yana nuna "hidden files/folders"
   (domin ka ga folder `.github` — a Windows: View > Show > Hidden items;
   a Mac: Cmd+Shift+.)
4. Ja (drag) **DUK** fayiloli da folders (har da `.github`, `scripts`,
   `lib`, `assets`, `pubspec.yaml`, `.gitignore`, `README.md`) zuwa
   shafin GitHub
5. Danna "Commit changes"

## Mataki 4 — Kirkiro Keystore (Signing Key)
Wannan shine mabuɗin da Google Play zai gane app ɗinka da shi — **kada ka
taɓa rasa shi ko manta password ɗin**, domin ba za ka iya sabunta app ɗin
akan Play Store ba tare da shi ba.

A kwamfutarka (idan kana da Java installed — `java -version` don duba),
bude Terminal/Command Prompt sannan ka rubuta:

```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Zai tambaye ka password (rubuta wanda za ka tuna, ka rubuta a wani wuri
mai aminci) da sunanka/kamfani (kowanne amsa ya isa, ba dole ne su zama
gaskiya 100% ba, sai dai password ɗin dole ne ya zama daidai koyaushe).

Idan ba ka da Java: shigar da "JDK" kawai (misali Eclipse Temurin) —
ba dole ne ka shigar da dukkan Android Studio ba.

## Mataki 5 — Mayar da Fayiloli zuwa Base64 (domin GitHub Secrets)

A Terminal/Command Prompt, a wurin da fayilolin suke:

**Keystore:**
```
# Mac/Linux:
base64 -i upload-keystore.jks -o keystore_base64.txt
# Windows PowerShell:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Out-File keystore_base64.txt
```

**google-services.json:**
```
# Mac/Linux:
base64 -i google-services.json -o google_services_base64.txt
# Windows PowerShell:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("google-services.json")) | Out-File google_services_base64.txt
```

Bude waɗannan .txt fayiloli guda biyu, ka kwafa (copy) abin da ke ciki
(dogon rubutu ne, babu matsala).

## Mataki 6 — Saka Secrets a GitHub
A shafin repo: Settings > Secrets and variables > Actions > "New
repository secret". Ƙirƙiro guda biyar, **sunayen dole su zama daidai
haka**:

| Sunan Secret | Darajarsa (Value) |
|---|---|
| `KEYSTORE_BASE64` | abin da ke cikin keystore_base64.txt |
| `KEYSTORE_PASSWORD` | password ɗin keystore da ka rubuta a Mataki 4 |
| `KEY_ALIAS` | `upload` (idan ka bi umarnin daidai haka) |
| `KEY_PASSWORD` | password iri ɗaya da KEYSTORE_PASSWORD (sai dai idan ka zaɓi daban lokacin keytool) |
| `GOOGLE_SERVICES_JSON_BASE64` | abin da ke cikin google_services_base64.txt |

## Mataki 7 — Fara Gina App ɗin
1. Je zuwa tab "Actions" a saman repo ɗin
2. Danna "Build Android App Bundle" a hagu
3. Danna "Run workflow" > "Run workflow" (kore button)
4. Jira minti 5-10, sai ka ga alamar ✅ kore

## Mataki 8 — Sauke .aab ɗinka
1. Danna cikin build ɗin da ya kammala (mai ✅)
2. A ƙasa, cikin sashin "Artifacts", danna "app-release-aab"
3. Zai sauko a matsayin zip — buɗe shi, `app-release.aab` ke ciki —
   wannan shine fayil ɗin da za ka tura Google Play Console

## Idan Gyara Ake Bukata Nan Gaba
Kawai ka gyara fayil (misali a `lib/screens/...`) kai tsaye a GitHub
(danna fensir ɗin edit) ko ka sake tura sabon fayil ta hanyar "Upload
files", sannan ka maimaita Mataki 7 — sabon `.aab` zai fito, **ba
bukatar sake yin Mataki 1-6 ba**.

## Idan Build ɗin Ya Kasa (Ja/Red ❌)
Danna cikin build ɗin da ya kasa, ka kwafa (copy) rubutun kuskuren
(error) da ka gani, ka aiko min shi anan — zan gyara script/workflow
ɗin daidai da kuskuren.
