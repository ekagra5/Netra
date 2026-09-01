"""
Fine-tunes MobileNetV2 on IDRiD + APTOS + ODIR-5K for three outputs:
  - dr_grade: DR severity, 5 classes (0-4)          [IDRiD, APTOS]
  - dme: DME risk, 3 classes (0-2)                  [IDRiD only]
  - ocular: 8 independent findings (multi-label)    [ODIR only]
    N=normal, D=diabetes, G=glaucoma, C=cataract, A=AMD, H=hypertension,
    M=myopia, O=other
Each dataset only has labels for some outputs; sample weights mask out
the losses a given row can't supervise (e.g. APTOS rows get zero weight
on the dme and ocular losses).

Saves the result as model.tflite (float32, matching the original model's format).

Usage: .venv/bin/python train_model.py
"""

import csv
import os
import random

# TF 2.16's default Keras 3 path crashes the TFLite converter on this
# machine's MobileNetV2 (MLIR "missing attribute 'value'" error). The
# legacy Keras 2 path (needs the matching tf-keras==2.16.0 package) avoids it.
os.environ.setdefault("TF_USE_LEGACY_KERAS", "1")

import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models

DATA_ROOT = "/Users/ekagra/Downloads/B. Disease Grading"
TRAIN_IMG_DIR = f"{DATA_ROOT}/1. Original Images/a. Training Set"
TEST_IMG_DIR = f"{DATA_ROOT}/1. Original Images/b. Testing Set"
TRAIN_CSV = f"{DATA_ROOT}/2. Groundtruths/a. IDRiD_Disease Grading_Training Labels.csv"
TEST_CSV = f"{DATA_ROOT}/2. Groundtruths/b. IDRiD_Disease Grading_Testing Labels.csv"

APTOS_ROOT = "/Users/ekagra/Downloads/aptos2019"
APTOS_IMG_DIR = f"{APTOS_ROOT}/train_images"
APTOS_CSV = f"{APTOS_ROOT}/train.csv"

ODIR_ROOT = "/Users/ekagra/Downloads/odir5k"
ODIR_IMG_DIR = f"{ODIR_ROOT}/Training Images"
ODIR_CSV = f"{ODIR_ROOT}/full_df.csv"
ODIR_LABELS = ["N", "D", "G", "C", "A", "H", "M", "O"]

IMG_SIZE = 224
BATCH_SIZE = 16
SEED = 42
NUM_GRADES = 5
NUM_DME = 3
NUM_OCULAR = len(ODIR_LABELS)

random.seed(SEED)
tf.random.set_seed(SEED)

# Row format: (path, grade, dme, ocular, has_grade, has_dme, has_ocular)
# ocular is an 8-float list; unused fields are 0/zeros placeholders.


def load_labels(csv_path, img_dir):
    """IDRiD: has both grade and DME labels."""
    rows = []
    with open(csv_path) as f:
        reader = csv.reader(f)
        next(reader)
        for row in reader:
            if len(row) < 3 or row[1] == "" or row[2] == "":
                continue
            path = f"{img_dir}/{row[0]}.jpg"
            if os.path.exists(path):
                rows.append((path, int(row[1]), int(row[2]), [0.0] * NUM_OCULAR, True, True, False))
    return rows


def load_aptos_labels(csv_path, img_dir):
    """APTOS: grade only, no DME."""
    rows = []
    with open(csv_path) as f:
        reader = csv.reader(f)
        next(reader)
        for row in reader:
            if len(row) < 2 or row[1] == "":
                continue
            path = f"{img_dir}/{row[0]}.png"
            if os.path.exists(path):
                rows.append((path, int(row[1]), 0, [0.0] * NUM_OCULAR, True, False, False))
    return rows


def load_odir_labels(csv_path, img_dir):
    """ODIR-5K: 8-way multi-label ocular findings, no DR grade/DME.
    One row per patient covering both eyes; both eye images get the same
    patient-level label (standard simplification for this dataset)."""
    rows = []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                ocular = [float(row[c]) for c in ODIR_LABELS]
            except (KeyError, ValueError):
                continue
            for col in ("Left-Fundus", "Right-Fundus"):
                name = row.get(col, "")
                if not name:
                    continue
                path = f"{img_dir}/{name}"
                if os.path.exists(path):
                    rows.append((path, 0, 0, ocular, False, False, True))
    return rows


def stratified_split(rows, val_fraction=0.15):
    by_grade = {}
    for r in rows:
        by_grade.setdefault(r[1], []).append(r)
    train, val = [], []
    rng = random.Random(SEED)
    for grade, items in by_grade.items():
        rng.shuffle(items)
        n_val = max(1, int(len(items) * val_fraction))
        val += items[:n_val]
        train += items[n_val:]
    rng.shuffle(train)
    rng.shuffle(val)
    return train, val


def random_split(rows, val_fraction=0.15):
    rng = random.Random(SEED)
    rows = rows[:]
    rng.shuffle(rows)
    n_val = max(1, int(len(rows) * val_fraction))
    return rows[n_val:], rows[:n_val]


def oversample_by_grade(rows, cap=4):
    """Repeats rows from underrepresented grades so each epoch sees a more
    balanced mix. Only meaningful for grade-labeled rows (IDRiD/APTOS)."""
    counts = np.zeros(NUM_GRADES)
    for r in rows:
        counts[r[1]] += 1
    max_count = counts.max()

    balanced = []
    for r in rows:
        repeat = min(cap, max(1, round(max_count / counts[r[1]])))
        balanced += [r] * repeat
    return balanced


def oversample_ocular(rows, cap=4):
    """Repeats ODIR rows containing rare positive findings (hypertension,
    glaucoma, AMD, myopia are all under 6% prevalence) so the model sees
    them often enough to learn them instead of always predicting "no"."""
    counts = np.zeros(NUM_OCULAR)
    for r in rows:
        counts += np.array(r[3])
    max_count = max(counts.max(), 1)

    balanced = []
    for r in rows:
        ocular = np.array(r[3])
        if ocular.sum() == 0:
            repeat = 1
        else:
            rarest = counts[ocular == 1].min()
            repeat = min(cap, max(1, round(max_count / rarest)))
        balanced += [r] * repeat
    return balanced


def make_dataset(rows, training):
    paths = [r[0] for r in rows]
    grades = [r[1] for r in rows]
    dmes = [r[2] for r in rows]
    oculars = [r[3] for r in rows]
    has_grade = [float(r[4]) for r in rows]
    has_dme = [float(r[5]) for r in rows]
    has_ocular = [float(r[6]) for r in rows]

    ds = tf.data.Dataset.from_tensor_slices(
        (paths, grades, dmes, oculars, has_grade, has_dme, has_ocular)
    )

    def load(path, grade, dme, ocular, hg, hd, ho):
        img = tf.io.read_file(path)
        # decode_image (not decode_jpeg): APTOS/ODIR are .png/.jpg mixed
        img = tf.io.decode_image(img, channels=3, expand_animations=False)
        img = tf.image.resize(img, [IMG_SIZE, IMG_SIZE])
        return img, grade, dme, ocular, hg, hd, ho

    ds = ds.map(load, num_parallel_calls=tf.data.AUTOTUNE)

    if training:
        def augment(img, grade, dme, ocular, hg, hd, ho):
            img = tf.image.random_flip_left_right(img)
            img = tf.image.random_flip_up_down(img)
            img = tf.image.random_brightness(img, 0.15)
            img = tf.image.random_contrast(img, 0.85, 1.15)
            img = tf.clip_by_value(img, 0.0, 255.0)
            return img, grade, dme, ocular, hg, hd, ho
        ds = ds.map(augment, num_parallel_calls=tf.data.AUTOTUNE)

    def preprocess(img, grade, dme, ocular, hg, hd, ho):
        img = tf.keras.applications.mobilenet_v2.preprocess_input(img)
        labels = {"dr_grade": grade, "dme": dme, "ocular": ocular}
        sample_weight = {"dr_grade": hg, "dme": hd, "ocular": ho}
        return img, labels, sample_weight

    ds = ds.map(preprocess, num_parallel_calls=tf.data.AUTOTUNE)

    if training:
        ds = ds.shuffle(256, seed=SEED)
    return ds.batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)


def build_model():
    base = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3), include_top=False, weights="imagenet"
    )
    base.trainable = False

    x = layers.GlobalAveragePooling2D()(base.output)
    x = layers.Dropout(0.3)(x)

    grade_out = layers.Dense(NUM_GRADES, activation="softmax", name="dr_grade")(x)
    dme_out = layers.Dense(NUM_DME, activation="softmax", name="dme")(x)
    ocular_out = layers.Dense(NUM_OCULAR, activation="sigmoid", name="ocular")(x)

    model = models.Model(base.input, [grade_out, dme_out, ocular_out])
    return model, base


LOSSES = {
    "dr_grade": "sparse_categorical_crossentropy",
    "dme": "sparse_categorical_crossentropy",
    "ocular": "binary_crossentropy",
}
METRICS = {"dr_grade": "accuracy", "dme": "accuracy", "ocular": "binary_accuracy"}
# DR grade is the core screening task; without this, gradients from the
# (much larger) ocular task pull the shared backbone away from what's
# optimal for grading, since all three losses update the same trunk.
LOSS_WEIGHTS = {"dr_grade": 2.0, "dme": 1.5, "ocular": 1.0}


def main():
    idrid_train = load_labels(TRAIN_CSV, TRAIN_IMG_DIR)
    # test set is always IDRiD-only, so accuracy stays comparable across runs
    test_rows = load_labels(TEST_CSV, TEST_IMG_DIR)
    idrid_train, idrid_val = stratified_split(idrid_train)

    grade_train = idrid_train
    val_rows = idrid_val

    have_aptos = os.path.exists(APTOS_CSV)
    if have_aptos:
        aptos_train = load_aptos_labels(APTOS_CSV, APTOS_IMG_DIR)
        aptos_train, aptos_val = stratified_split(aptos_train)
        grade_train = idrid_train + aptos_train
        val_rows = val_rows + aptos_val
        print(f"IDRiD train={len(idrid_train)}  APTOS train={len(aptos_train)}")
    else:
        print("APTOS not found, training on IDRiD only")

    train_rows = oversample_by_grade(grade_train)
    print(f"grade-labeled train after oversampling: {len(train_rows)}")

    have_odir = os.path.exists(ODIR_CSV)
    if have_odir:
        odir_rows = load_odir_labels(ODIR_CSV, ODIR_IMG_DIR)
        odir_train, odir_val = random_split(odir_rows)
        odir_train_balanced = oversample_ocular(odir_train)
        train_rows = train_rows + odir_train_balanced
        val_rows = val_rows + odir_val
        print(f"ODIR train={len(odir_train)} -> {len(odir_train_balanced)} after oversampling  ODIR val={len(odir_val)}")
    else:
        print("ODIR not found, training without ocular findings head")

    print(f"train={len(train_rows)} val={len(val_rows)} test={len(test_rows)}")

    train_ds = make_dataset(train_rows, training=True)
    val_ds = make_dataset(val_rows, training=False)
    test_ds = make_dataset(test_rows, training=False)

    model, base = build_model()

    # legacy optimizer: the current tf.keras.optimizers.Adam is slow on Apple Silicon
    model.compile(
        optimizer=tf.keras.optimizers.legacy.Adam(1e-3),
        loss=LOSSES,
        loss_weights=LOSS_WEIGHTS,
        weighted_metrics=METRICS,
    )

    print("\n--- Phase 1: frozen backbone ---")
    model.fit(train_ds, validation_data=val_ds, epochs=14)

    print("\n--- Phase 2: fine-tune last layers ---")
    base.trainable = True
    for layer in base.layers[:-60]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.legacy.Adam(1e-5),
        loss=LOSSES,
        loss_weights=LOSS_WEIGHTS,
        weighted_metrics=METRICS,
    )
    model.fit(train_ds, validation_data=val_ds, epochs=20)

    # Note: an earlier IDRiD-only "recalibration" phase 3 was tried and made
    # things worse on this small a test set (see project notes) - dropped.

    print("\n--- Test set evaluation (DR grade + DME, IDRiD only) ---")
    results = model.evaluate(test_ds, return_dict=True)
    print(results)

    if have_odir:
        print("\n--- Ocular findings evaluation (ODIR val split) ---")
        odir_val_ds = make_dataset(odir_val, training=False)
        odir_results = model.evaluate(odir_val_ds, return_dict=True)
        print(odir_results)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    with open("model.tflite", "wb") as f:
        f.write(tflite_model)
    print("\nSaved model.tflite")


if __name__ == "__main__":
    main()
