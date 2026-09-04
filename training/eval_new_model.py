"""
Confusion matrix + accuracy for DR grade and DME on the 103 held-out
IDRiD test images (excluded from training on Kaggle too).

Ocular findings aren't checked here - the only ODIR/RFMiD data available
locally already went into training, so evaluating on it would be leakage.
"""

import csv
import sys

import numpy as np
from PIL import Image

try:
    from tflite_runtime.interpreter import Interpreter
except ImportError:
    import tensorflow as tf
    Interpreter = tf.lite.Interpreter

MODEL_PATH = sys.argv[1] if len(sys.argv) > 1 else "model_apex_v2.tflite"
TEST_IMG_DIR = "/Users/ekagra/Downloads/B. Disease Grading/1. Original Images/b. Testing Set"
TEST_CSV = "/Users/ekagra/Downloads/B. Disease Grading/2. Groundtruths/b. IDRiD_Disease Grading_Testing Labels.csv"

NORMALIZE_TO_MINUS1_1 = True
NUM_GRADES = 5
NUM_DME = 3


def preprocess(pil_image, input_details):
    _, h, w, _ = input_details["shape"]
    arr = np.array(pil_image.resize((w, h))).astype(np.float32)
    if input_details["dtype"] == np.float32:
        arr = arr / 255.0
        if NORMALIZE_TO_MINUS1_1:
            arr = arr * 2.0 - 1.0
    else:
        scale, zero_point = input_details["quantization"]
        arr = arr / 255.0
        if NORMALIZE_TO_MINUS1_1:
            arr = arr * 2.0 - 1.0
        arr = (arr / scale + zero_point).astype(input_details["dtype"])
    return np.expand_dims(arr, axis=0)


def dequantize(raw, details):
    out = raw.astype(np.float32)
    if details["dtype"] != np.float32:
        scale, zero_point = details["quantization"]
        out = (out - zero_point) * scale
    return out


def to_probs(raw, details):
    out = dequantize(raw, details)
    if not np.isclose(out.sum(), 1.0, atol=0.05):
        exp = np.exp(out - np.max(out))
        out = exp / exp.sum()
    return out


def run(interpreter, input_details, output_details, tensor):
    interpreter.set_tensor(input_details["index"], tensor)
    interpreter.invoke()
    grade_probs = dme_probs = None
    for d in output_details:
        raw = interpreter.get_tensor(d["index"])[0]
        if raw.shape[0] == NUM_GRADES:
            grade_probs = to_probs(raw, d)
        elif raw.shape[0] == NUM_DME:
            dme_probs = to_probs(raw, d)
    return grade_probs, dme_probs


def confusion_matrix(y_true, y_pred, n):
    cm = np.zeros((n, n), dtype=int)
    for t, p in zip(y_true, y_pred):
        cm[t, p] += 1
    return cm


def report(name, y_true, y_pred, n, labels):
    cm = confusion_matrix(y_true, y_pred, n)
    overall = np.trace(cm) / cm.sum() * 100
    print(f"\n{name} - overall accuracy: {overall:.1f}% ({np.trace(cm)}/{cm.sum()})")
    print(f"{'':22s}" + "".join(f"pred={i:<6}" for i in range(n)) + "  recall")
    for i in range(n):
        row = cm[i]
        recall = row[i] / row.sum() * 100 if row.sum() else float("nan")
        print(f"true={i} {labels[i][:14]:14s}" + "".join(f"{v:<10d}" for v in row) + f"{recall:5.1f}%  (n={row.sum()})")


def main():
    print(f"Loading {MODEL_PATH}")
    interpreter = Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()

    rows = []
    with open(TEST_CSV) as f:
        for row in csv.DictReader(f):
            code = row["Image name"].strip()
            if not code:
                continue
            rows.append((code, int(row["Retinopathy grade"]), int(row["Risk of macular edema "])))

    y_true_grade, y_pred_grade, y_true_dme, y_pred_dme = [], [], [], []
    for code, grade, dme in rows:
        path = f"{TEST_IMG_DIR}/{code}.jpg"
        img = Image.open(path).convert("RGB")
        tensor = preprocess(img, input_details)
        grade_probs, dme_probs = run(interpreter, input_details, output_details, tensor)
        y_true_grade.append(grade)
        y_pred_grade.append(int(np.argmax(grade_probs)))
        if dme_probs is not None:
            y_true_dme.append(dme)
            y_pred_dme.append(int(np.argmax(dme_probs)))

    grade_labels = ["No DR", "Mild", "Moderate", "Severe", "Proliferative"]
    dme_labels = ["No risk", "Some risk", "High risk"]
    report("DR GRADE (5-class)", y_true_grade, y_pred_grade, NUM_GRADES, grade_labels)
    if y_true_dme:
        report("DME (3-class)", y_true_dme, y_pred_dme, NUM_DME, dme_labels)
    print(f"\nTest set: {len(rows)} real IDRiD images, held out from training on Kaggle too.")


if __name__ == "__main__":
    main()
