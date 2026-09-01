"""
Downloads APTOS 2019 train_images individually (not the full competition
bundle, which includes unneeded test images and can stall while Kaggle
zips ~9GB server-side). Uses a thread pool since each file is a separate
authenticated request.
"""

import csv
import os
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed

from PIL import Image
from kaggle.api.kaggle_api_extended import KaggleApi

COMPETITION = "aptos2019-blindness-detection"
CSV_PATH = "/Users/ekagra/Downloads/aptos2019/train.csv"
OUT_DIR = "/Users/ekagra/Downloads/aptos2019/train_images"
WORKERS = 2
MAX_RETRIES = 3
REQUEST_DELAY = 1.0  # fixed pause after every request, success or not


def load_ids():
    with open(CSV_PATH) as f:
        reader = csv.reader(f)
        next(reader)
        return [row[0] for row in reader if row]


def unwrap_if_zipped(path):
    """Kaggle's per-file endpoint sometimes wraps the response in a zip
    container instead of raw bytes. Detect and unwrap it in place."""
    with open(path, "rb") as f:
        head = f.read(2)
    if head != b"PK":
        return
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        data = z.read(names[0])
    with open(path, "wb") as f:
        f.write(data)


def is_valid_image(path):
    try:
        with Image.open(path) as img:
            img.verify()
        return True
    except Exception:
        return False


def download_one(api, image_id):
    out_path = f"{OUT_DIR}/{image_id}.png"
    if os.path.exists(out_path):
        if is_valid_image(out_path):
            return True
        os.remove(out_path)  # corrupted from a previous run, redo it

    for attempt in range(MAX_RETRIES):
        try:
            api.competition_download_file(
                COMPETITION, f"train_images/{image_id}.png", path=OUT_DIR, quiet=True
            )
            unwrap_if_zipped(out_path)
            if is_valid_image(out_path):
                time.sleep(REQUEST_DELAY)
                return True
            os.remove(out_path)
            raise ValueError("downloaded file failed image validation")
        except Exception as e:
            is_rate_limit = "429" in str(e)
            if attempt == MAX_RETRIES - 1:
                print(f"FAILED {image_id}: {e}")
                return False
            time.sleep(30 if is_rate_limit else 1)
    return False


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    ids = load_ids()
    print(f"downloading {len(ids)} images with {WORKERS} workers")

    api = KaggleApi()
    api.authenticate()

    start = time.time()
    done = 0
    failed = 0
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = {pool.submit(download_one, api, i): i for i in ids}
        for future in as_completed(futures):
            ok = future.result()
            done += 1
            if not ok:
                failed += 1
            if done % 100 == 0 or done == len(ids):
                elapsed = time.time() - start
                rate = done / elapsed if elapsed > 0 else 0
                eta = (len(ids) - done) / rate if rate > 0 else 0
                print(f"{done}/{len(ids)}  failed={failed}  {rate:.1f}/s  ETA {eta/60:.1f}min")

    print(f"done in {(time.time()-start)/60:.1f} min, failed={failed}")


if __name__ == "__main__":
    main()
