#!/usr/bin/env bash
set -euo pipefail

ROOT="${WAN22_ROOT:-$PWD/.wan22}"
REPO="$ROOT/Wan2.2"
VENV="$ROOT/venv"
MODEL_DIR="${WAN22_MODEL_DIR:-$ROOT/models/Wan2.2-Animate-14B}"
mkdir -p "$ROOT" "$ROOT/models"

command -v git >/dev/null
command -v python3 >/dev/null

if [ ! -d "$REPO/.git" ]; then
  git clone --depth 1 https://github.com/Wan-Video/Wan2.2.git "$REPO"
else
  git -C "$REPO" fetch --depth 1 origin main
  git -C "$REPO" reset --hard origin/main
fi

python3 -m venv "$VENV"
source "$VENV/bin/activate"
python -m pip install -U pip wheel setuptools
# Official requirement: torch >= 2.4.0. Let the host select the CUDA wheel already configured.
python -m pip install -r "$REPO/requirements.txt"
python -m pip install 'huggingface_hub[cli]'

if [ "${WAN22_DOWNLOAD_MODEL:-1}" = "1" ]; then
  huggingface-cli download Wan-AI/Wan2.2-Animate-14B --local-dir "$MODEL_DIR"
fi

python - <<'PY'
import json, os, subprocess, sys
root=os.environ.get('WAN22_ROOT', os.path.join(os.getcwd(), '.wan22'))
repo=os.path.join(root,'Wan2.2')
model=os.environ.get('WAN22_MODEL_DIR', os.path.join(root,'models','Wan2.2-Animate-14B'))
try:
    import torch
    cuda=torch.cuda.is_available()
    n=torch.cuda.device_count() if cuda else 0
    names=[torch.cuda.get_device_name(i) for i in range(n)]
    torch_ver=torch.__version__
except Exception as e:
    cuda=False; n=0; names=[]; torch_ver=f'ERROR:{e}'
commit=subprocess.check_output(['git','-C',repo,'rev-parse','HEAD'], text=True).strip()
manifest={
  'toolchain':'Wan2.2-Animate-14B',
  'repo_commit':commit,
  'python':sys.version.split()[0],
  'torch':torch_ver,
  'cuda_available':cuda,
  'gpu_count':n,
  'gpu_names':names,
  'model_dir':model,
  'model_present':os.path.isdir(model) and any(os.scandir(model)),
}
os.makedirs(os.path.join(root,'state'),exist_ok=True)
path=os.path.join(root,'state','manifest.json')
json.dump(manifest,open(path,'w'),indent=2)
print(json.dumps(manifest,indent=2))
if not cuda:
    raise SystemExit('WAN22_GPU_REQUIRED: no CUDA GPU available')
if not manifest['model_present']:
    raise SystemExit('WAN22_MODEL_REQUIRED: model not present')
print('WAN22_BOOTSTRAP: PASS')
PY
