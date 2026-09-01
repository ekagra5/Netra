# Netra

Diabetic retinopathy screening from a single fundus photo, built for SIH26038
(rural India context — non-specialist health workers, not ophthalmologists).
Runs fully on-device via TFLite, no server-side inference.

Given a photo, it grades DR severity (0-4), flags macular swelling (DME)
risk, checks for 6 other eye conditions, and shows an occlusion-sensitivity
heatmap of what the model actually reacted to. It's a screening aid, not a
diagnosis — the point is to tell a health worker who needs a specialist
visit, not to replace one.

## Model

MobileNetV2 backbone, three heads sharing one feature extractor (DR grade,
DME, ocular findings). Trained in two stages — heads only with the backbone
frozen, then the last ~60 backbone layers unfrozen and fine-tuned at a lower
learning rate. Since no single dataset labels all three outputs, each row's
loss is masked to only the heads it has ground truth for.

Explainability is occlusion sensitivity (patch the image, measure the
confidence drop), not Grad-CAM — a `.tflite` model has no backprop access
for Grad-CAM to hook into.

## Data

IDRiD, APTOS 2019, EyePACS (2015, resized), ODIR-5K, and RFMiD combined:
86,393 training images, 8,215 validation, 80 held out (IDRiD's own test
split, kept out of training). Oversampled the underrepresented classes —
grade-labeled rows to 62,475, ocular rows to 23,918. Trained on a Kaggle P100
for about 5.4 hours.

## Accuracy

Measured on the 103 IDRiD test images (`eval_new_model.py`), never touched
during training:

- DR grade, 5-class exact match: **45.6%**
- DME, 3-class exact match: **58.3%**

It leans toward mid/severe predictions — "Mild" DR and "some risk" DME
currently get 0% recall. That's a real effect of stitching together
datasets with different label distributions, not something we're hiding.
Ocular-finding accuracy isn't independently validated yet; the only ODIR
data we have locally was already used in training, so testing on it
wouldn't mean anything.

For context: 95% DR-grade accuracy isn't realistic at this scale. 65-80% is
a fair ceiling with a lot more data and compute than we had here.

## Running it

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/streamlit run apex_app.py
```

`train_model.py` is what actually trained the model — it ran as a Kaggle
Notebook (GPU P100) with all five datasets attached as inputs, so the
`/kaggle/input/...` paths only resolve there. To rerun it: new Kaggle
notebook, attach the five datasets listed above, paste the script in, run.

Re-run the accuracy check:

```bash
.venv/bin/python eval_new_model.py
```

## Files

- `apex_app.py` — the app (English/Hindi, patient details, downloadable
  report, heatmap)
- `model_apex_v2.tflite` — the trained model (not in this repo yet — ask
  for access)
- `train_model.py` — the actual Kaggle training pipeline
- `eval_new_model.py` — held-out test evaluation
