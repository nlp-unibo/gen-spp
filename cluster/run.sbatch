#!/bin/bash
#SBATCH --job-name=genspp-release
#SBATCH --array=1-5
#SBATCH --partition=l40s
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --gres=gpu:1
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%A_%a.log

# Trains GenSPP on one corpus, one seed per array task. Submit from the
# repository root:
#
#   sbatch --array=1 cluster/run.sbatch toy --smoke    # one generation of two individuals
#   sbatch cluster/run.sbatch toy                      # seeds 1 to 5
#   sbatch cluster/run.sbatch hatexplain
#
# The array index is the seed. `train.py --n=5` runs seeds 1 to 5 in one
# process, which exceeds the cluster's 24-hour limit on Toy. Each task
# therefore calls `run_training` once with its own seed.
#
# Results are written to `genetic/results/outputs/` as `metrics_<corpus>_<seed>.txt`
# and `masks_<corpus>_<seed>.txt`. The smoke run writes `smoke_<corpus>_<seed>`.
#
# `GENSPP_PROBE` selects a variance probe arm, described in
# `genetic/src/utils/config.py`. With an arm set, the files are named
# `<corpus>_probe-<arm>_<seed>`, so the arms never overwrite each other or the
# unprobed run:
#
#   GENSPP_PROBE=noval sbatch --array=1-20 cluster/run.sbatch toy

set -euo pipefail

CORPUS=${1:?usage: sbatch cluster/run.sbatch <toy|hatexplain> [--smoke]}
SMOKE=0
if [ "${2:-}" = "--smoke" ]; then
  SMOKE=1
fi
SEED=${SLURM_ARRAY_TASK_ID:-1}
PROBE=${GENSPP_PROBE:-}
SCRATCH=${SCRATCH:-/scratch.hpc/${USER:-$(id -un)}}

if [ ! -f env.sif ]; then
  echo "missing $PWD/env.sif, run cluster/build.sbatch first" >&2
  exit 2
fi

# HateXplain reads 25-dimensional Twitter GloVe from `genetic/data/glove/twitter/`.
# The file is 1.4 GB and is not part of the repository. Set `GLOVE` to its path.
if [ "$CORPUS" = "hatexplain" ]; then
  GLOVE=${GLOVE:-$SCRATCH/glove/glove.twitter.27B.25d.txt}
  if [ ! -f "$GLOVE" ]; then
    echo "missing $GLOVE, see genetic/data/glove/README.md" >&2
    exit 2
  fi
  ln -sf "$GLOVE" genetic/data/glove/twitter/glove.twitter.27B.25d.txt
fi

cd genetic

apptainer exec --nv \
  --bind "$PWD:$PWD" --bind "$SCRATCH:$SCRATCH" \
  --env PYTHONUNBUFFERED=1 \
  --env GENSPP_PROBE="${PROBE:-none}" \
  ../env.sif python - "$CORPUS" "$SEED" "$SMOKE" "$PROBE" <<'PY'
import sys

import torch

import train

corpus, seed, smoke, probe = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "1", sys.argv[4]
name = f"{corpus}_probe-{probe}" if probe else corpus
if smoke:
    train.N_GENERATIONS = 1
    train.POPULATION_SIZE = 2
    name = f"smoke_{name}"
train.set_random_seed(seed)
metrics = train.run_training(
    corpus, name, 1, seed, torch.device("cuda"), plot_train_loss=False
)
print("FINAL", corpus, seed, metrics)
PY
