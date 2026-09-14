#!/bin/bash
# 종류 하나만 여러 계수로: bash tests/sweep_type.sh "<몬스터 레벨>" "<계수들>" "<공통 인자>" [판수]
G="/c/Users/조영래/OneDrive/Desktop/Godot/Godot_v4.7.1-stable_win64.exe"
N=${4:-120}
for tf in $2; do
  r=$(timeout 110 "$G" --headless res://tests/battle_sim.tscn -- $N $1 stages $3 tf=$tf 2>&1)
  echo "  $1 tf=$tf: $(echo "$r" | grep 승률 | sed 's/승률 *: //') | 남은체력 $(echo "$r" | grep '남은 체력' | sed 's/.*: //') | $(echo "$r" | grep 패배 | sed 's/패배 지점 *: //')"
done
