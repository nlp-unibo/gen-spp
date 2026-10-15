# Interlocking-free Selective Rationalization Through Genetic-based Learning

Official repository of "Interlocking-free Selective Rationalization Through Genetic-based Learning".

## Structure

We split GenSPP and selective rationalization baselines in two standalone projects: ``genetic``, and `baselines`.

### Genetic

Please, see the README.md file in ``genetic`` folder.

### Baselines

Please, see the README.md file in ``baseline`` folder.

### Slurm cluster

The `cluster` folder runs GenSPP on a Slurm cluster inside an Apptainer image.
The image is built from `cluster/env.def` with the versions that `genetic/requirements.txt` pins.
Submit every job from the repository root:

```bash
mkdir -p logs
sbatch cluster/build.sbatch                       # builds env.sif
sbatch --array=1 cluster/run.sbatch toy --smoke   # one generation of two individuals
sbatch cluster/run.sbatch toy                     # seeds 1 to 5, one GPU job each
sbatch cluster/run.sbatch hatexplain              # needs GloVe, see below
```

Each array task trains one seed, and the array index is the seed.
Results are written to `genetic/results/outputs/`.
HateXplain reads `glove.twitter.27B.25d.txt`, which is not part of the repository.
Set `GLOVE` to its path when it is not at `$SCRATCH/glove/glove.twitter.27B.25d.txt`.
The partitions are `sbuild` for the build and `l40s` for training; override them with `sbatch --partition=<name>`.

## Issues

Don't hesitate to file an issue if you find some bugs!

## Contact

- [Federico Ruggeri](federico.ruggeri6@unibo.it)
- [Gaetano Signorelli](gaetano.signorelli2@unibo.it)

## Cite

```
@inproceedings{ruggeri-signorelli-2025-interlocking,
    title = "Interlocking-free Selective Rationalization Through Genetic-based Learning",
    author = "Ruggeri, Federico  and
      Signorelli, Gaetano",
    editor = "Che, Wanxiang  and
      Nabende, Joyce  and
      Shutova, Ekaterina  and
      Pilehvar, Mohammad Taher",
    booktitle = "Proceedings of the 63rd Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)",
    month = jul,
    year = "2025",
    address = "Vienna, Austria",
    publisher = "Association for Computational Linguistics",
    url = "https://aclanthology.org/2025.acl-long.59/",
    doi = "10.18653/v1/2025.acl-long.59",
    pages = "1175--1191",
    ISBN = "979-8-89176-251-0",
    abstract = "A popular end-to-end architecture for selective rationalization is the select-then-predict pipeline, comprising a generator to extract highlights fed to a predictor. Such a cooperative system suffers from suboptimal equilibrium minima due to the dominance of one of the two modules, a phenomenon known as interlocking. While several contributions aimed at addressing interlocking, they only mitigate its effect, often by introducing feature-based heuristics, sampling, and ad-hoc regularizations. We present GenSPP, the first interlocking-free architecture for selective rationalization that does not require any learning overhead, as the above-mentioned. GenSPP avoids interlocking by performing disjoint training of the generator and predictor via genetic global search. Experiments on a synthetic and a real-world benchmark show that our model outperforms several state-of-the-art competitors."
}
```

## Credits

Eleonora Misino, Paolo Torroni

## Acknowledgments

This publication is supported by the project European Commission’s NextGeneration EU programme, PNRR – M4C2 – Investimento 1.3, Partenariato Esteso, PE00000013 - “FAIR - Future Artificial Intelligence Research” – Spoke 8 “Pervasive AI” and by the European Union’s Justice Programme under Grant Agreement No. 101087342 for the project “Principles Of Law In National and European VAT”.
