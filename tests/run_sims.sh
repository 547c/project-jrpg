#!/bin/bash
# 여러 설정의 밸런스 시뮬레이션을 한 번에 돌린다: bash tests/run_sims.sh [판수]
G="/c/Users/조영래/OneDrive/Desktop/Godot/Godot_v4.7.1-stable_win64.exe"
N=${1:-150}
F='^ERROR: BUG\|at: unref\|RID alloc\|PagedAllocator\|Thread object\|wait_to_finish\|at: ~\|leaked\|resources still\|^Godot Engine\|^$'
for cfg in "ORC 1" "ORC 3" "SKELETON 5" "MUMMY 8"; do
  echo ">>> $cfg"
  timeout 110 "$G" --headless res://tests/battle_sim.tscn -- $N $cfg 2>&1 | grep -v "$F" | grep -v "^==="
done
