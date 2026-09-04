# Credits & acknowledgments

## Training data

The model was trained on five public retinal-imaging datasets, combined and
oversampled to balance class representation. Each keeps its own license and
citation terms - check the source before redistributing the data itself
(the trained model weights are covered by this repo's own LICENSE, not by
the datasets' licenses).

- **IDRiD** - Indian Diabetic Retinopathy Image Dataset.
  Porwal, P. et al. "Indian Diabetic Retinopathy Image Dataset (IDRiD)."
  IEEE Dataport, 2018. https://idrid.grand-challenge.org/
  Also the source of this project's held-out test set (103 images never
  used in training).
- **APTOS 2019 Blindness Detection** - Asia Pacific Tele-Ophthalmology
  Society, via Kaggle. https://www.kaggle.com/competitions/aptos2019-blindness-detection
- **EyePACS / Diabetic Retinopathy Detection (2015)** - EyePACS, via Kaggle.
  https://www.kaggle.com/competitions/diabetic-retinopathy-detection
- **ODIR-5K** - Ocular Disease Intelligent Recognition, Peking University.
  https://odir2019.grand-challenge.org/
- **RFMiD** - Retinal Fundus Multi-disease Image Dataset.
  Pachade, S. et al. "Retinal Fundus Multi-Disease Image Dataset (RFMiD): A
  Dataset for Multi-Disease Detection Research." Data, 2021.
  https://riadd.grand-challenge.org/

## Model & training approach

MobileNetV2 backbone (ImageNet-pretrained) with three task heads sharing one
feature extractor, fine-tuned in two stages. See [README.md](README.md) for
the full architecture description and honest accuracy numbers, and
[train_model.py](training/train_model.py) for the actual training script.

## Open-source packages

This app is built on the Flutter/Dart ecosystem and would not exist without
the maintainers of, among others: `tflite_flutter`, `image`, `image_picker`,
`sqflite`, `pdf` / `printing`, `provider`, and `connectivity_plus`. See
[pubspec.yaml](pubspec.yaml) for the full dependency list and each
package's own license on pub.dev.

## Origin

Originally built for **Smart India Hackathon 2026**, problem statement
PSSIH26038 ("Explainable AI for Diabetic Retinopathy Screening in Rural
India"), by **Team Apex**. This repository is the post-hackathon,
continued-development version.
