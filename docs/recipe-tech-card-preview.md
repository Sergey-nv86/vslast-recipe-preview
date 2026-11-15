# Recipe technology cards — isolated preview setup

## Current development phase: on-device OCR

The current UI performs only local OCR in the browser using Tesseract.js 5.1.1 and the Russian `rus` language model. Recognition runs on the user's device in WebAssembly; selected photos are converted to data URLs in memory and are not sent to Supabase or Gemini during OCR. The first run downloads the OCR engine, WebAssembly core and Russian trained data from public CDNs; Tesseract.js caches language data in browser IndexedDB. Internet access is therefore required for the first initialization. Cloud AI parsing is intentionally not connected to the screen until iPhone OCR testing is accepted.

The source branch imported from `vslast-premium` is a baseline snapshot. Uncommitted local-only changes from the Mac working tree were not present on GitHub and are not claimed as transferred.

This feature is isolated in repository `vslast-recipe-preview`, branch `feature/local-tesseract-ocr`.

## What it does

- Admin / production roles can open «Технологические карты» from the admin dashboard.
- The screen accepts up to eight recipe photos.
- The current screen extracts editable Russian text locally from up to eight photos. It does not call the recipe-tech-card Edge Function.
- The existing recipe-tech-card Edge Function is retained for a later AI phase, but is not invoked by the current OCR-only UI.

## Cloud AI phase — intentionally paused

Do not add or expose `GEMINI_API_KEY` during the OCR-only phase. The cloud function remains separate and unused by the screen. AI integration begins only after local OCR has been tested and accepted on iPhone.

## Database and deployment

1. The isolated preview project has already received the profile bootstrap and recipe TTK migrations.
2. The recipe-tech-card Edge Function has already been deployed to the preview project.
4. The isolated preview database is separate from production. No production Supabase project is modified by this repository.
5. The OCR-only preview must be tested on iPhone Safari before any cloud AI integration.

Do not apply this migration or deploy the function to vslast-production until the preview has been accepted.

## Calculation boundaries

- Recipe amounts in grams/kilograms and millilitres/litres are converted only within the same dimension.
- Pieces are not converted to grams without a known piece weight.
- Cups, spoons, pinches and other volume/weight measures without ingredient-specific density are not guessed; the recipe needs manual correction.
- Missing purchase prices leave the total cost incomplete.
- Nutrition is calculated only when ingredient nutrition data, compatible gram quantities and a known finished yield are available. Generic starter nutrition values are marked as estimates and should be checked against supplier labels.
- This is a draft TTK assistant; the technologist must confirm ambiguous handwriting, yields, losses, storage conditions and nutrition before operational use.

## Isolated mobile preview project

The preview Supabase project is already provisioned separately from production:

- Project: `vslast-recipe-tech-preview`
- Project ref: `lpuzgzgyxqfwnwpfbefw`
- Region: `eu-central-1`
- Project URL: `https://lpuzgzgyxqfwnwpfbefw.supabase.co`
- Organization: `snocwyuqqemdvxwkywxf`
- Project creation estimate: USD 0/month

The preview app has a dedicated email/password entry screen. In this repository `RECIPE_PREVIEW` defaults to `true`, and Supabase defaults to the isolated preview project even when no Dart defines are supplied. This repository must never be used to build production. The first account registered in this isolated preview project receives the owner role; later accounts receive customer role. This first-account rule is specific to this unshared test project and must never be copied to production.

Active publishable key for the preview app (safe for client-side use):
`sb_publishable_VSsRlb6ITGZrWa6oz70HsQ_mQkfJfJi`

From the repository root, build/run the preview variant:

```bash
flutter pub get
flutter run \
  --dart-define=RECIPE_PREVIEW=true \
  --dart-define=SUPABASE_URL=https://lpuzgzgyxqfwnwpfbefw.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_VSsRlb6ITGZrWa6oz70HsQ_mQkfJfJi
```

For iPhone installation, open `ios/Runner.xcworkspace` in Xcode, select the iPhone and a valid Apple development signing team, then run the same preview build. A signed iOS build requires the user's Apple signing identity.

### Deploy the web preview to the isolated Firebase Hosting site

Run these commands from the root of this repository after signing in to Firebase CLI. Do not use the production app repository or its Firebase configuration.

```bash
flutter pub get
flutter build web --release \\
  --dart-define=RECIPE_PREVIEW=true \\
  --dart-define=SUPABASE_URL=https://lpuzgzgyxqfwnwpfbefw.supabase.co \\
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_VSsRlb6ITGZrWa6oz70HsQ_mQkfJfJi
firebase deploy --only hosting --project vslast-recipe-tech --config firebase.recipe-preview.json
```

The deploy command targets only the isolated preview Firebase project `vslast-recipe-tech`. It does not deploy Cloud Functions, database migrations, or any production Firebase resources.


The first registration may require email confirmation depending on the Auth email settings. The profile trigger assigns owner only to the first account in this isolated preview project; the function is not executable through the public Data API. After confirmation, sign in with the same test email/password. No production users or data are present in this project.

## Remaining before iPhone OCR acceptance

1. Run the Flutter analyze and web release build workflow.
2. Publish only to the isolated preview Firebase site after validation.
3. Test Russian OCR on iPhone Safari with printed, photographed and slightly rotated recipe pages.
4. Check text quality, memory use, first-run loading time and repeat-run cache behavior.
5. Correct OCR problems before connecting any cloud AI.

## Later AI phase (do not execute yet)

1. Only after OCR acceptance, decide whether to enable the existing preview Edge Function.
2. Keep any AI key in the preview Supabase Edge Function secrets, never in GitHub or Flutter.
