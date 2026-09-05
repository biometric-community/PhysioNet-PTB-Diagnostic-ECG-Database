# PTB Diagnostic ECG Database

[![License: ODC-By 1.0](https://img.shields.io/badge/License-ODC--By%201.0-green)](https://opendatacommons.org/licenses/by/1-0/)
[![Access: public](https://img.shields.io/badge/access-public-0e8a16.svg)](https://physionet.org/content/ptbdb/1.0.0/)

**PTB Diagnostic ECG Database** — high-resolution 15-lead ECGs (12 standard + Frank XYZ) with clinical summaries; PhysioNet open access.

- **Upstream source**: https://physionet.org/content/ptbdb/1.0.0/
- **DOI**: https://doi.org/10.13026/C28C71
- **Original archive**: `ptbdb-1.0.0.zip` (~1.7 GiB)
- **License (data)**: [Open Data Commons Attribution License v1.0](https://opendatacommons.org/licenses/by/1-0/) (PhysioNet)
- **License (helpers / docs)**: CC BY 4.0 (see [`LICENSE`](LICENSE))

| Field | Value |
|-------|-------|
| Catalog id (tbiom) | `ptb` |
| Category | `physio` |
| Access | `public` |
| Upstream homepage | https://physionet.org/content/ptbdb/1.0.0/ |

> **Note:** This folder is the classic **PTB Diagnostic ECG** (`ptbdb`). PhysioNet’s separate **PTB-XL** corpus is a different project and is not bundled here.

## TL;DR

- **Task**: diagnostic ECG analysis / pathology classification / benchmarking
- **Modality**: 15-lead ECG (WFDB `.dat` / `.hea`)
- **Platform**: PTB prototype recorder (clinical + healthy volunteers)
- **Real/Synthetic**: real
- **Subjects**: **290** patient folders (local count; IDs skip 124, 132, 134, 161)
- **Records**: **549** (`.hea` / `.dat` pairs; 1–5 records per subject)
- **Leads**: 12 standard + 3 Frank (`vx`, `vy`, `vz`)
- **Sampling**: 1000 Hz, 16-bit, ± ±16.384 mV
- **Clinical summaries**: embedded in most `.hea` files (missing for 22 subjects upstream)
- **Archive**: ~1.7 GiB zip → GitHub-safe shards under `parts/` via `setup.sh`
- **Citation**: Bousseljot et al., Biomed. Tech. 1995 (+ PhysioNet citation)

## Table of contents

- [Download](#download)
- [Dataset structure](#dataset-structure)
- [Annotation schema](#annotation-schema)
- [Stats and splits](#stats-and-splits)
- [Quick start](#quick-start)
- [Evaluation and baselines](#evaluation-and-baselines)
- [Datasheet (data card)](#datasheet-data-card)
- [Known issues and caveats](#known-issues-and-caveats)
- [License](#license)
- [Citation](#citation)
- [Contact](#contact)

## Download

- **This folder**: GitHub-safe shards under [`parts/`](parts/) (`ptbdb-1.0.0.zip.part000`, …, plus [`parts/MANIFEST.txt`](parts/MANIFEST.txt)). After `bash setup.sh restore`, data lands under `extracted/`.
- **Upstream ZIP**: https://physionet.org/content/ptbdb/1.0.0/ — place as `ptbdb-1.0.0.zip`, then `bash setup.sh prepare`.
- **Helper script** (from tbiom repo root):

```bash
bash projects/datasets/scripts/download_ptb.sh
```

### GitHub-safe shards (&lt;100 MiB)

`ptbdb-1.0.0.zip` is ~1.7 GiB and far exceeds GitHub’s 100 MiB limit:

```bash
cd projects/datasets/ptb
bash setup.sh prepare   # verify + split into parts/ (95 MiB each by default)
bash setup.sh restore   # cat parts → unzip into extracted/
bash setup.sh verify    # integrity check only
```

- The full zip is removed after a successful `prepare`
- Override chunk size: `CHUNK_SIZE=90M bash setup.sh prepare`

## Dataset structure

```text
ptb/
├── README.md
├── LICENSE
├── STATUS.md
├── setup.sh
├── parts/
│   ├── MANIFEST.txt
│   ├── ptbdb-1.0.0.zip.part000
│   └── ...
├── ptb-diagnostic-ecg-database-1.0.0/   # local extract (often not committed)
│   ├── RECORDS
│   ├── patient001/
│   │   ├── s0010_re.hea
│   │   ├── s0010_re.dat
│   │   └── ...
│   └── patient294/
└── extracted/                           # created by setup.sh restore
    └── ptb-diagnostic-ecg-database-1.0.0/
        └── ...
```

- **Splits**: no official ML train/val/test partition in the zip.
- **Layout notes**: one directory per subject (`patientNNN`); each record uses WFDB basenames such as `s0010_re`.

## Annotation schema

### WFDB records (`patient*/s*_re.hea`, `.dat`)

- **`.hea`**: sampling rate, gains, lead names, and (for most records) clinical summary text
- **`.dat`**: binary multi-lead ECG samples
- **Coordinates**: time is sample index at 1000 Hz
- **Example paths** (verified locally):

```text
ptb-diagnostic-ecg-database-1.0.0/patient001/s0010_re.hea
ptb-diagnostic-ecg-database-1.0.0/patient001/s0010_re.dat
```

Use [WFDB](https://physionet.org/content/wfdb/) / `wfdb` (Python) to read signals and header metadata.

### Diagnostic classes (upstream summary)

Among subjects with clinical summaries (268 of 290):

| Diagnostic class | Subjects |
|------------------|----------:|
| Myocardial infarction | 148 |
| Healthy controls | 52 |
| Cardiomyopathy / heart failure | 18 |
| Bundle branch block | 15 |
| Dysrhythmia | 14 |
| Myocardial hypertrophy | 7 |
| Valvular heart disease | 6 |
| Myocarditis | 4 |
| Miscellaneous | 4 |

## Stats and splits

Counts from the local extract:

| Measure | Count |
|---------|------:|
| Patient folders | 290 |
| Records (`.hea` / `.dat`) | 549 |
| Leads per record | 15 |
| Sample rate | 1000 Hz |
| Zip size (before shard) | ~1.7 GiB |

## Quick start

```bash
cd projects/datasets/ptb
bash setup.sh restore
```

```python
from pathlib import Path

root = Path("extracted/ptb-diagnostic-ecg-database-1.0.0")
# or Path("ptb-diagnostic-ecg-database-1.0.0") if already extracted
patients = sorted(p for p in root.glob("patient*") if p.is_dir())
heas = sorted(root.glob("patient*/*.hea"))
print(len(patients), "patients,", len(heas), "records")
print("example", heas[0])

# Optional: pip install wfdb
# import wfdb
# rec = heas[0].with_suffix("")
# sig, fields = wfdb.rdsamp(str(rec))
```

**Dependencies**: `bash`, `split`, `unzip` for `setup.sh`; optional `wfdb` for loading.

## Evaluation and baselines

- **Primary metrics**: pathology / MI classification accuracy, AUC, or paper-specific ECG metrics
- **Suggested baselines**: classical PTB diagnostic pipelines and modern ECG deep-learning papers citing this database
- **Baseline numbers**: not reproduced here — see citing literature

## Datasheet (data card)

### Motivation

Share a high-resolution, multi-lead diagnostic ECG corpus with clinical summaries for research and algorithm benchmarking.

### Composition

549 records from 290 subjects (ages ~17–87). Mix of healthy controls and multiple cardiac disease classes.

### Collection process

Recorded with a PTB prototype device at University Clinic Benjamin Franklin (Berlin); prepared for PhysioNet by PTB / Charité collaborators.

### Preprocessing

Distributed in PhysioNet WFDB format at 1000 Hz (higher rates available from contributors on special request).

### Distribution

- **Signal / header files**: ODC-By 1.0 via PhysioNet
- **Helpers / docs in this folder**: CC BY 4.0 (`LICENSE`)

### Maintenance

Shard with `setup.sh prepare`; restore with `setup.sh restore`. Re-download via `download_ptb.sh` if needed.

## Known issues and caveats

- Catalog id is `ptb` but this is **PTB Diagnostic ECG**, not **PTB-XL**
- Subject numbers are not contiguous (no 124, 132, 134, 161)
- Clinical summary missing for 22 subjects upstream
- Full archive is large (~1.7 GiB); prefer `parts/` for GitHub; keep local extract gitignored
- No official train/test split — define folds carefully to avoid patient leakage

## License

**Data files** are licensed under **[ODC-By 1.0](https://opendatacommons.org/licenses/by/1-0/)** as published by PhysioNet.

**Packaging helpers / docs** in this folder are **[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)**. See [`LICENSE`](LICENSE).

## Citation

```bibtex
@article{Bousseljot1995PTB,
  title   = {Nutzung der {EKG}-Signaldatenbank {CARDIODAT} der {PTB} \"uber das Internet},
  author  = {Bousseljot, R. and Kreiseler, D. and Schnabel, A.},
  journal = {Biomedizinische Technik},
  volume  = {40},
  number  = {Erg{\"a}nzungsband 1},
  pages   = {317},
  year    = {1995}
}

@misc{ptbdb100,
  title        = {{PTB} Diagnostic {ECG} Database},
  author       = {{Physikalisch-Technische Bundesanstalt (PTB)}},
  howpublished = {PhysioNet},
  year         = {2004},
  note         = {Version 1.0.0},
  doi          = {10.13026/C28C71},
  url          = {https://physionet.org/content/ptbdb/1.0.0/}
}
```

Also include the current PhysioNet platform citation required on the project page.

## Contact

- **Upstream**: https://physionet.org/content/ptbdb/1.0.0/
- **tbiom catalog**: `projects/datasets/ptb/`
