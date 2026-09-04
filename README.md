# Netra

On-device diabetic retinopathy (DR) screening from a single retina photo —
built for rural primary health centers, where the person taking the photo
is a health worker, not an ophthalmologist, and there may be no reliable
internet connection at all.

Given a fundus photo, the model grades DR severity (0–4), flags diabetic
macular edema (DME) risk, and screens for six other eye conditions
(glaucoma, cataract, AMD, hypertension signs, myopia signs, other), with an
occlusion-sensitivity heatmap showing what it actually reacted to. Every
result routes low-confidence or borderline cases to a "needs specialist
review" flow instead of guessing. **It's a screening aid, not a diagnosis**
— the point is to tell a health worker who needs a specialist visit, not to
replace an ophthalmologist.

## Not a medical device

This is a research/hackathon project, not a certified diagnostic tool. It
has not gone through clinical validation or regulatory clearance (no FDA,
CDSCO, or CE marking). Do not use it to make an actual treatment decision.
See [Accuracy](#accuracy) below for exactly how good the current model is —
and isn't.

## App

A Flutter app (`app/`) — offline-first, bilingual (English/Hindi), running
the model fully on-device via `tflite_flutter`. No photo or patient data
ever leaves the device unless a health worker explicitly shares a generated
PDF report.

```
app/
  lib/
    screens/       one file per screen (onboarding, capture, results, ...)
    state/         single ChangeNotifier driving navigation + the scan flow
    services/      on-device inference, local SQLite storage, PDF report
    widgets/       shared chrome (header, tab bar, card, tag, ...)
    theme.dart      design tokens
    i18n/           English/Hindi strings
  assets/models/    model_apex_v2.tflite goes here (see below)
```

### Running it

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) and
either Xcode (iOS) or Android Studio (Android) set up for your platform.

```bash
cd app
flutter pub get
flutter run
```

The model file isn't tracked if you cloned before it was added — see
[Model](#model) below for where to get it and where it goes.

## Model

MobileNetV2 backbone, three heads sharing one feature extractor (DR grade,
DME, ocular findings). Trained in two stages — heads only with the backbone
frozen, then the last ~60 backbone layers unfrozen and fine-tuned at a lower
learning rate. Since no single dataset labels all three outputs, each row's
loss is masked to only the heads it has ground truth for.

Explainability is occlusion sensitivity (patch the image, measure the
confidence drop), not Grad-CAM — a `.tflite` model has no backprop access
for Grad-CAM to hook into.

### Data

IDRiD, APTOS 2019, EyePACS (2015, resized), ODIR-5K, and RFMiD combined:
86,393 training images, 8,215 validation, 80 held out (IDRiD's own test
split, kept out of training). Oversampled the underrepresented classes —
grade-labeled rows to 62,475, ocular rows to 23,918. Trained on a Kaggle
P100 for about 5.4 hours. Full dataset citations in
[CREDITS.md](CREDITS.md).

### Accuracy

Measured on the 103 IDRiD test images (`training/eval_new_model.py`), never
touched during training:

- DR grade, 5-class exact match: **45.6%**
- DME, 3-class exact match: **58.3%**

It leans toward mid/severe predictions — "Mild" DR and "some risk" DME
currently get 0% recall. That's a real effect of stitching together
datasets with different label distributions, not something we're hiding.
Ocular-finding accuracy isn't independently validated yet; the only ODIR
data available locally was already used in training, so testing on it
wouldn't mean anything.

For context: 95% DR-grade accuracy isn't realistic at this scale. 65–80% is
a fair ceiling with a lot more data and compute than this project had.

### Training / evaluation scripts

```
training/
  train_model.py       the actual Kaggle training pipeline
  eval_new_model.py     held-out test evaluation
  requirements.txt      Python deps for the two scripts above
```

`train_model.py` ran as a Kaggle Notebook (GPU P100) with all five datasets
attached as inputs, so the `/kaggle/input/...` paths only resolve there. To
rerun it: new Kaggle notebook, attach the five datasets listed in
[CREDITS.md](CREDITS.md), paste the script in, run.

```bash
cd training
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python eval_new_model.py model_apex_v2.tflite path/to/images path/to/labels.csv
```

## Known limitations / roadmap

- The offline sync queue is real local state (SQLite-backed, survives app
  restarts) but there is currently no backend to actually sync *to* — "Sync
  now" marks queued scans as synced locally. Wiring up a real clinic-server
  endpoint is the next real milestone, not a cosmetic one.
- The occlusion-sensitivity heatmap uses a coarse 8×8 grid (64 forward
  passes) to stay fast on a mid-range phone. Finer-grained heatmaps are
  possible at the cost of speed.
- See [Accuracy](#accuracy) above for the model's real, current limits.

## License

[MIT](LICENSE) for the app and training code. See [CREDITS.md](CREDITS.md)
for the training datasets' own licenses and citation requirements, which
this repo's MIT license does not cover.

## Origin

Originally built for **Smart India Hackathon 2026**, problem statement
PSSIH26038, by **Team Apex**. This repository continues development after
the hackathon.
