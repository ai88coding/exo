# EXO Cluster Setup Guide

## Hardware

| Node | Model | RAM | GPU | Backend |
|------|-------|-----|-----|---------|
| Mac | Mac Studio M2 Ultra | 192GB | M2 Ultra (72-core) | MlxMetal |
| sparka | DGX Spark GB10 | 128GB | NVIDIA GB10 (compute 12.1) | MlxCuda |
| sparkb | DGX Spark GB10 | 128GB | NVIDIA GB10 (compute 12.1) | MlxCuda |

## Prerequisites

### All nodes
- Python 3.13+ with `uv`
- EXO repo cloned: `git clone https://github.com/exo-explore/exo.git && cd exo`
- Custom MLX fork (ring backend support):
  - Mac: `rltakashige/mlx-jaccl-fix-small-recv` (Metal)
  - Linux: same fork (CUDA) via `--extra mlx-cuda13`

### SSH Keys
- Mac has SSH key access to sparka and sparkb as `admin@sparka`, `admin@sparkb`
- sparka/sparkb have SSH key access to Mac

## Installation

### Mac (macOS)
```bash
git clone https://github.com/exo-explore/exo.git
cd exo
uv sync --group dev
```

### sparka / sparkb (Linux aarch64)
```bash
git clone https://github.com/exo-explore/exo.git
cd exo
uv sync --extra mlx-cuda13 --python 3.13.13
```

## Running

### Environment variables
All nodes must share the same namespace:
```bash
export EXO_LIBP2P_NAMESPACE=wilson-cluster
```

Mac additionally loads models from LM Studio:
```bash
export EXO_MODELS_READ_ONLY_DIRS=~/.lmstudio/models
```

### Start
On each node:
```bash
cd /path/to/exo
EXO_LIBP2P_NAMESPACE=wilson-cluster uv run exo
```

Mac with LM Studio model dir:
```bash
EXO_MODELS_READ_ONLY_DIRS=~/.lmstudio/models EXO_LIBP2P_NAMESPACE=wilson-cluster uv run exo
```

Dashboard available at `http://<node-ip>:52415`.

## Model Management

### Model directory
- **Mac**: Models stored in `~/.lmstudio/models/` (LM Studio managed)
- **sparka/sparkb**: Models stored in `~/.local/share/exo/models/`
- Mac uses `EXO_MODELS_READ_ONLY_DIRS` to read LM Studio models without copying

### Sync model from Mac to sparka/sparkb
```bash
# On sparka or sparkb
rsync -avz wilson@<mac-ip>:~/.lmstudio/models/mlx-community/MODEL_NAME/ \
  ~/.local/share/exo/models/mlx-community/MODEL_NAME/
```

### Dashboard node ordering
Nodes in the topology graph are sorted by system memory (descending), so the most powerful node (Mac, 192GB) appears at the 12 o'clock position. This is determined in:
- `dashboard/src/lib/components/TopologyGraph.svelte`
- `dashboard/src/lib/components/ModelCard.svelte`

## Known Issues

### Model download synchronization
When a model is selected from the dashboard, each node independently triggers a download. If a model is already downloaded on Mac (in LM Studio), it is NOT automatically rsynced to sparka/sparkb. All nodes start downloading instead of using Mac's local copy.

**Planned fix**: After a download completes on any node, automatically rsync the model directory to other nodes in the cluster.