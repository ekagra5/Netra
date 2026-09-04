"""
Trains the multi-head MobileNetV2 (DR grade + DME + ocular findings) on
IDRiD, APTOS, EyePACS, ODIR-5K, and RFMiD, then exports model.tflite.

This was run as a Kaggle Notebook (GPU P100) with all five datasets
attached as inputs - the paths below assume that environment, not a
local one. To reproduce: create a Kaggle notebook, attach the five
datasets, paste this in, run.
"""

import csv, os, random
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models

APTOS_CSV = '/kaggle/input/competitions/aptos2019-blindness-detection/train.csv'
APTOS_IMG_DIR = '/kaggle/input/competitions/aptos2019-blindness-detection/train_images'

IDRID_CSV = '/kaggle/input/datasets/mariaherrerot/idrid-dataset/idrid_labels.csv'
IDRID_IMG_DIR = '/kaggle/input/datasets/mariaherrerot/idrid-dataset/Imagenes/Imagenes'

ODIR_CSV = '/kaggle/input/datasets/andrewmvd/ocular-disease-recognition-odir5k/full_df.csv'
ODIR_IMG_DIR = '/kaggle/input/datasets/andrewmvd/ocular-disease-recognition-odir5k/preprocessed_images'
ODIR_LABELS = ['N', 'D', 'G', 'C', 'A', 'H', 'M', 'O']

EYEPACS_ROOT = '/kaggle/input/datasets/sovitrath/diabetic-retinopathy-2015-data-colored-resized/colored_images/colored_images'
EYEPACS_CLASSES = {'No_DR': 0, 'Mild': 1, 'Moderate': 2, 'Severe': 3, 'Proliferate_DR': 4}

RFMID_ROOT = '/kaggle/input/datasets/ozlemhakdagli/retinal-fundus-multi-disease-image-dataset-rfmid'
RFMID_SPLITS = [('Training_set', 'RFMiD_Training_Labels.csv'), ('Validation_set', 'RFMiD_Validation_Labels.csv'), ('Test_set', 'RFMiD_Testing_Labels.csv')]

IMG_SIZE = 224
BATCH_SIZE = 32
SEED = 42
NUM_GRADES = 5
NUM_DME = 3
NUM_OCULAR = len(ODIR_LABELS)

random.seed(SEED)
tf.random.set_seed(SEED)


# Row format: (path, grade, dme, ocular[8], ocular_mask[8], has_grade, has_dme)
# ocular_mask marks which of the 8 findings this row actually has a label for,
# since RFMiD only overlaps ODIR's ontology on D/A/M/N and the rest must be
# masked out rather than treated as confirmed negatives.


def load_idrid(csv_path, img_dir):
    train, test = [], []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            code = row.get('id_code', '')
            grade = row.get('diagnosis', '')
            dme = row.get('Risk of macular edema ', '')
            if not code or grade == '' or dme == '':
                continue
            path = f'{img_dir}/{code}.jpg'
            if not os.path.exists(path):
                continue
            entry = (path, int(float(grade)), int(float(dme)), [0.0] * NUM_OCULAR, [0.0] * NUM_OCULAR, True, True)
            if 'test' in code:
                test.append(entry)
            else:
                train.append(entry)
    return train, test

def load_aptos(csv_path, img_dir):
    rows = []
    with open(csv_path) as f:
        reader = csv.reader(f)
        next(reader)
        for row in reader:
            if len(row) < 2 or row[1] == '':
                continue
            path = f'{img_dir}/{row[0]}.png'
            if os.path.exists(path):
                rows.append((path, int(row[1]), 0, [0.0] * NUM_OCULAR, [0.0] * NUM_OCULAR, True, False))
    return rows

def load_eyepacs(root, classes):
    rows = []
    for name, grade in classes.items():
        folder = f'{root}/{name}'
        if not os.path.isdir(folder):
            continue
        for fname in os.listdir(folder):
            rows.append((f'{folder}/{fname}', grade, 0, [0.0] * NUM_OCULAR, [0.0] * NUM_OCULAR, True, False))
    return rows

def load_odir(csv_path, img_dir):
    rows = []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                ocular = [float(row[c]) for c in ODIR_LABELS]
            except (KeyError, ValueError):
                continue
            mask = [1.0] * NUM_OCULAR
            for col in ('Left-Fundus', 'Right-Fundus'):
                name = row.get(col, '')
                if not name:
                    continue
                path = f'{img_dir}/{name}'
                if os.path.exists(path):
                    rows.append((path, 0, 0, ocular, mask, False, False))
    return rows

def load_rfmid(root, splits):
    rows = []
    for folder, csv_name in splits:
        img_dir = f'{root}/{folder}'
        csv_path = f'{img_dir}/{csv_name}'
        if not os.path.exists(csv_path):
            continue
        with open(csv_path, encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            for row in reader:
                try:
                    risk = float(row['Disease_Risk'])
                    dr = float(row['DR'])
                    armd = float(row['ARMD'])
                    mya = float(row['MYA'])
                except (KeyError, ValueError):
                    continue
                path = f"{img_dir}/{row['ID']}.png"
                if not os.path.exists(path):
                    continue
                ocular = [0.0] * NUM_OCULAR
                mask = [0.0] * NUM_OCULAR
                ocular[ODIR_LABELS.index('D')] = dr
                mask[ODIR_LABELS.index('D')] = 1.0
                ocular[ODIR_LABELS.index('A')] = armd
                mask[ODIR_LABELS.index('A')] = 1.0
                ocular[ODIR_LABELS.index('M')] = mya
                mask[ODIR_LABELS.index('M')] = 1.0
                ocular[ODIR_LABELS.index('N')] = 1.0 - risk
                mask[ODIR_LABELS.index('N')] = 1.0
                rows.append((path, 0, 0, ocular, mask, False, False))
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
    counts = np.zeros(NUM_OCULAR)
    for r in rows:
        ocular = np.array(r[3])
        mask = np.array(r[4])
        counts += ocular * mask
    max_count = max(counts.max(), 1)
    balanced = []
    for r in rows:
        ocular = np.array(r[3])
        mask = np.array(r[4])
        positive = (ocular == 1) & (mask == 1)
        if not positive.any():
            repeat = 1
        else:
            rarest = counts[positive].min()
            repeat = min(cap, max(1, round(max_count / rarest)))
        balanced += [r] * repeat
    return balanced


def make_dataset(rows, training):
    paths = [r[0] for r in rows]
    grades = [r[1] for r in rows]
    dmes = [r[2] for r in rows]
    ocular_targets = [r[3] + r[4] for r in rows]
    has_grade = [float(r[5]) for r in rows]
    has_dme = [float(r[6]) for r in rows]

    ds = tf.data.Dataset.from_tensor_slices((paths, grades, dmes, ocular_targets, has_grade, has_dme))

    def load(path, grade, dme, ocular_target, hg, hd):
        img = tf.io.read_file(path)
        img = tf.io.decode_image(img, channels=3, expand_animations=False)
        img = tf.image.resize(img, [IMG_SIZE, IMG_SIZE])
        return img, grade, dme, ocular_target, hg, hd

    ds = ds.map(load, num_parallel_calls=tf.data.AUTOTUNE)

    if training:
        def augment(img, grade, dme, ocular_target, hg, hd):
            img = tf.image.random_flip_left_right(img)
            img = tf.image.random_flip_up_down(img)
            img = tf.image.random_brightness(img, 0.15)
            img = tf.image.random_contrast(img, 0.85, 1.15)
            img = tf.clip_by_value(img, 0.0, 255.0)
            return img, grade, dme, ocular_target, hg, hd
        ds = ds.map(augment, num_parallel_calls=tf.data.AUTOTUNE)

    def preprocess(img, grade, dme, ocular_target, hg, hd):
        img = tf.keras.applications.mobilenet_v2.preprocess_input(img)
        labels = {'dr_grade': grade, 'dme': dme, 'ocular': ocular_target}
        sample_weight = {'dr_grade': hg, 'dme': hd, 'ocular': 1.0}
        return img, labels, sample_weight
    ds = ds.map(preprocess, num_parallel_calls=tf.data.AUTOTUNE)

    if training:
        ds = ds.shuffle(256, seed=SEED)
    return ds.batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)


def masked_ocular_loss(y_true, y_pred):
    labels = y_true[:, :NUM_OCULAR]
    mask = y_true[:, NUM_OCULAR:]
    bce = tf.keras.backend.binary_crossentropy(labels, y_pred)
    bce = bce * mask
    denom = tf.reduce_sum(mask, axis=1) + 1e-8
    return tf.reduce_sum(bce, axis=1) / denom


def masked_ocular_accuracy(y_true, y_pred):
    labels = y_true[:, :NUM_OCULAR]
    mask = y_true[:, NUM_OCULAR:]
    correct = tf.cast(tf.equal(labels, tf.round(y_pred)), tf.float32) * mask
    denom = tf.reduce_sum(mask, axis=1) + 1e-8
    return tf.reduce_sum(correct, axis=1) / denom


def build_model():
    base = tf.keras.applications.MobileNetV2(input_shape=(IMG_SIZE, IMG_SIZE, 3), include_top=False, weights='imagenet')
    base.trainable = False
    x = layers.GlobalAveragePooling2D()(base.output)
    x = layers.Dropout(0.3)(x)
    grade_out = layers.Dense(NUM_GRADES, activation='softmax', name='dr_grade')(x)
    dme_out = layers.Dense(NUM_DME, activation='softmax', name='dme')(x)
    ocular_out = layers.Dense(NUM_OCULAR, activation='sigmoid', name='ocular')(x)
    model = models.Model(base.input, {'dr_grade': grade_out, 'dme': dme_out, 'ocular': ocular_out})
    return model, base

LOSSES = {'dr_grade': 'sparse_categorical_crossentropy', 'dme': 'sparse_categorical_crossentropy', 'ocular': masked_ocular_loss}
METRICS = {'dr_grade': 'accuracy', 'dme': 'accuracy', 'ocular': masked_ocular_accuracy}
LOSS_WEIGHTS = {'dr_grade': 2.0, 'dme': 1.5, 'ocular': 1.0}


idrid_train, test_rows = load_idrid(IDRID_CSV, IDRID_IMG_DIR)
idrid_train, idrid_val = stratified_split(idrid_train)
grade_train = idrid_train
val_rows = idrid_val
print(f'IDRiD train={len(idrid_train)} val={len(idrid_val)} test={len(test_rows)}')

aptos_rows = load_aptos(APTOS_CSV, APTOS_IMG_DIR)
aptos_train, aptos_val = stratified_split(aptos_rows)
grade_train = grade_train + aptos_train
val_rows = val_rows + aptos_val
print(f'APTOS train={len(aptos_train)} val={len(aptos_val)}')

eyepacs_rows = load_eyepacs(EYEPACS_ROOT, EYEPACS_CLASSES)
eyepacs_train, eyepacs_val = stratified_split(eyepacs_rows)
grade_train = grade_train + eyepacs_train
val_rows = val_rows + eyepacs_val
print(f'EyePACS train={len(eyepacs_train)} val={len(eyepacs_val)}')

train_rows = oversample_by_grade(grade_train)
print(f'grade-labeled train after oversampling: {len(train_rows)}')

odir_rows = load_odir(ODIR_CSV, ODIR_IMG_DIR)
odir_train, odir_val = random_split(odir_rows)

rfmid_rows = load_rfmid(RFMID_ROOT, RFMID_SPLITS)
rfmid_train, rfmid_val = random_split(rfmid_rows)

ocular_train = oversample_ocular(odir_train + rfmid_train)
train_rows = train_rows + ocular_train
val_rows = val_rows + odir_val + rfmid_val
print(f'ODIR train={len(odir_train)} RFMiD train={len(rfmid_train)} -> {len(ocular_train)} after oversampling')
print(f'train={len(train_rows)} val={len(val_rows)} test={len(test_rows)}')


train_ds = make_dataset(train_rows, training=True)
val_ds = make_dataset(val_rows, training=False)
test_ds = make_dataset(test_rows, training=False)

model, base = build_model()
model.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss=LOSSES, loss_weights=LOSS_WEIGHTS, weighted_metrics=METRICS)

print('Phase 1: frozen backbone')
model.fit(train_ds, validation_data=val_ds, epochs=14)
model.save('phase1_model.keras')


print('Phase 2: fine-tune last layers')
base.trainable = True
for layer in base.layers[:-60]:
    layer.trainable = False

model.compile(optimizer=tf.keras.optimizers.Adam(1e-5), loss=LOSSES, loss_weights=LOSS_WEIGHTS, weighted_metrics=METRICS)
model.fit(train_ds, validation_data=val_ds, epochs=20)
model.save('final_model.keras')


from sklearn.metrics import confusion_matrix, classification_report

y_true_grade, y_pred_grade, y_true_dme, y_pred_dme = [], [], [], []
for imgs, labels, _ in test_ds:
    preds = model.predict(imgs, verbose=0)
    y_true_grade += labels['dr_grade'].numpy().tolist()
    y_pred_grade += np.argmax(preds['dr_grade'], axis=1).tolist()
    y_true_dme += labels['dme'].numpy().tolist()
    y_pred_dme += np.argmax(preds['dme'], axis=1).tolist()

print('DR grade confusion matrix (rows=true, cols=pred):')
print(confusion_matrix(y_true_grade, y_pred_grade))
print(classification_report(y_true_grade, y_pred_grade, digits=3))

print('DME confusion matrix:')
print(confusion_matrix(y_true_dme, y_pred_dme))
print(classification_report(y_true_dme, y_pred_dme, digits=3))


ocular_val_rows = odir_val + rfmid_val
ocular_val_ds = make_dataset(ocular_val_rows, training=False)

y_true_ocular, y_pred_ocular, mask_ocular = [], [], []
for imgs, labels, _ in ocular_val_ds:
    preds = model.predict(imgs, verbose=0)
    target = labels['ocular'].numpy()
    y_true_ocular.append(target[:, :NUM_OCULAR])
    mask_ocular.append(target[:, NUM_OCULAR:])
    y_pred_ocular.append((preds['ocular'] > 0.5).astype(float))

y_true_ocular = np.concatenate(y_true_ocular)
y_pred_ocular = np.concatenate(y_pred_ocular)
mask_ocular = np.concatenate(mask_ocular)

print('Ocular findings per-class, only over rows with a known label:')
for i, name in enumerate(ODIR_LABELS):
    known = mask_ocular[:, i] == 1
    if known.sum() == 0:
        print(f'{name}: no labeled examples')
        continue
    print(f'{name}:')
    print(classification_report(y_true_ocular[known, i], y_pred_ocular[known, i], digits=3, zero_division=0))


converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open('model.tflite', 'wb') as f:
    f.write(tflite_model)
print('Saved model.tflite')
