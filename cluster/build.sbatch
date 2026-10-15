#!/bin/bash
#SBATCH --job-name=genspp-build
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=sbuild
#SBATCH --output=logs/build_%j.log

# Builds `env.sif` from `cluster/env.def`. Submit from the repository root:
#
#   mkdir -p logs && sbatch cluster/build.sbatch

set -euo pipefail

# Apptainer writes many small files while it assembles the image, so its cache
# and temporary files live on the node's local disk. One directory per job
# keeps concurrent builds apart.
# ponytail: assumes about 20 GB of free local disk; add a scratch fallback if a node has less.
LOCAL="${TMPDIR:-/tmp}/${USER:-$(id -un)}-apptainer-${SLURM_JOB_ID:-$$}"
export APPTAINER_CACHEDIR="$LOCAL/cache"
export APPTAINER_TMPDIR="$LOCAL/tmp"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"
trap 'rm -rf "$LOCAL"' EXIT

# `--ignore-fakeroot-command` is required when the user has no `/etc/subuid`
# entry. Without it, apptainer injects a host `libfakeroot.so` that needs a
# newer glibc than the Ubuntu 22.04 base provides, and `%post` fails.
#
# The registry sometimes resets the connection while it serves the base image,
# so the build is attempted three times.
for attempt in 1 2 3; do
  if apptainer build --ignore-fakeroot-command --force env.sif cluster/env.def; then
    echo "built $PWD/env.sif"
    exit 0
  fi
  echo "build failed (attempt $attempt)" >&2
  sleep 60
done
exit 1
