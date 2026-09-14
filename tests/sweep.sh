#!/bin/bash
# 밸런스 스윕: bash tests/sweep.sh "<덮어쓰기 인자>" [판수]
G="/c/Users/조영래/OneDrive/Desktop/Godot/Godot_v4.7.1-stable_win64.exe"
N=${2:-120}
F='^ERROR: BUG\|at: unref\|RID alloc\|PagedAllocator\|Thread object\|wait_to_finish\|at: ~\|leaked\|resources still\|^Godot Engine\|^$'
echo "### $1"
for cfg in "ORC 1" "SKELETON 5" "MUMMY 8"; do
  r=$(timeout 110 "$G" --headless res://tests/battle_sim.tscn -- $N $cfg stages $1 2>&1 | grep -v "$F")
  echo "  $cfg: $(echo "$r" | grep 승률 | sed "s/승률 *: //") | 교착 $(echo "$r" | grep 교착 | sed "s/.*: //") | 남은체력 $(echo "$r" | grep '남은 체력' | sed 's/.*: //') | $(echo "$r" | grep '레드라인' | sed 's/판당 //') | $(echo "$r" | grep '적응  ' | sed 's/판당 //') | $(echo "$r" | grep '표식' | sed 's/판당 //') | $(echo "$r" | grep 패배 | sed 's/패배 지점 *: //')"
done
