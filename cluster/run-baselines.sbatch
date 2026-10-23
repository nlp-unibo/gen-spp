#!/bin/bash
#SBATCH --job-name=baselines-release
#SBATCH --array=1-4
#SBATCH --partition=l40s
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --gres=gpu:1
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%A_%a.log

# Trains one release baseline on one corpus, all five of its seeds, per array
# task. Submit from the repository root after `sbatch cluster/build.sbatch
# env-baselines`:
#
#   sbatch --array=1 cluster/run-baselines.sbatch toy --smoke   # FR, one epoch per seed
#   sbatch cluster/run-baselines.sbatch toy
#   sbatch cluster/run-baselines.sbatch hatexplain
#
# The array index selects the model: 1 is FR, 2 MGR, 3 MCD and 4 G-RAT.
# Each runs `baselines/runnables/<corpus>_<model>_train.py`, which loops over
# the seeds of its configuration in one process.
#
# Results are written to `baselines/results/<corpus>/<model>/`. A runnable
# skips training for a seed that already has a checkpoint there. The smoke run
# therefore trains a copy of `baselines/` on the node's local disk, beside a
# link to `genetic/` for the data, and deletes that copy when the job ends.

set -euo pipefail

CORPUS=${1:?usage: sbatch cluster/run-baselines.sbatch <toy|hatexplain> [--smoke]}
SMOKE=0
if [ "${2:-}" = "--smoke" ]; then
  SMOKE=1
fi
MODELS=(fr mgr mcd grat)
MODEL=${MODELS[$(( ${SLURM_ARRAY_TASK_ID:-1} - 1 ))]}
SCRATCH=${SCRATCH:-/scratch.hpc/${USER:-$(id -un)}}

if [ ! -f env-baselines.sif ]; then
  echo "missing $PWD/env-baselines.sif, run cluster/build.sbatch env-baselines first" >&2
  exit 2
fi

BASELINES=$PWD/baselines
if [ "$SMOKE" = "1" ]; then
  WORK="${TMPDIR:-/tmp}/${USER:-$(id -un)}-baselines-${SLURM_JOB_ID:-$$}"
  mkdir -p "$WORK"
  trap 'rm -rf "$WORK"' EXIT
  cp -a baselines "$WORK/"
  ln -s "$PWD/genetic" "$WORK/genetic"
  BASELINES=$WORK/baselines
fi

# HateXplain reads 25-dimensional Twitter GloVe through torchtext, which writes
# a `.pt` cache beside the text file on first use. Each task reads a link to
# the text file from its own directory, so concurrent tasks never read a cache
# another task is still writing.
if [ "$CORPUS" = "hatexplain" ]; then
  GLOVE=${GLOVE:-$SCRATCH/glove/glove.twitter.27B.25d.txt}
  if [ ! -f "$GLOVE" ]; then
    echo "missing $GLOVE, see genetic/data/glove/README.md" >&2
    exit 2
  fi
  GLOVE_DIR="${TMPDIR:-/tmp}/${USER:-$(id -un)}-glove-${SLURM_JOB_ID:-$$}"
  mkdir -p "$GLOVE_DIR"
  trap 'rm -rf "$GLOVE_DIR" "${WORK:-}"' EXIT
  ln -sf "$GLOVE" "$GLOVE_DIR/glove.twitter.27B.25d.txt"
fi

apptainer exec --nv \
  --bind "$PWD:$PWD" --bind "$SCRATCH:$SCRATCH" \
  --bind "${TMPDIR:-/tmp}:${TMPDIR:-/tmp}" \
  --env PYTHONUNBUFFERED=1 --env PYTHONPATH="$BASELINES" \
  --env GLOVE_DIR="${GLOVE_DIR:-}" \
  env-baselines.sif python - "$BASELINES/runnables/${CORPUS}_${MODEL}_train.py" "$SMOKE" <<'PY'
import os
import runpy
import sys

import lightning

script, smoke = sys.argv[1], sys.argv[2] == "1"
if not os.environ.get("GLOVE_DIR"):
    os.environ.pop("GLOVE_DIR", None)
if smoke:
    class SmokeTrainer(lightning.Trainer):
        def __init__(self, *args, **kwargs):
            kwargs.update(max_epochs=1, limit_train_batches=2, limit_val_batches=2,
                          limit_test_batches=2)
            super().__init__(*args, **kwargs)

    lightning.Trainer = SmokeTrainer
sys.argv = [script]
runpy.run_path(script, run_name="__main__")
PY
