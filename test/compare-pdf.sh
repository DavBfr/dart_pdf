#!/bin/bash

DST=$(dirname "$0")/diff
SRC=$1
GOLD=$2
ERROR=0
DPI=50
COMPARE=$(command -v compare)

for PDF in "$SRC"/*.pdf; do
  echo "Diffing $PDF"
  G="$GOLD"/$(basename "$PDF")
  if [ ! -f "$G" ]; then
    echo "   Golden image $G not found"
    ERROR=1
    continue
  fi

  T=$(basename "$PDF" .pdf)
  mkdir -p "$DST"/"$T"
  pdftocairo "$PDF" -png -r "$DPI" "$DST"/"$T"/src 2> /dev/null
  pdftocairo "$G" -png -r "$DPI" "$DST"/"$T"/gold 2> /dev/null

  for PNG in "$DST"/"$T"/gold*.png; do
    S="$DST"/"$T"/src-"${PNG##*-}"
    RES=$($COMPARE -metric AE "$PNG" "$S" null: 2>&1)
    RES=$(echo "$RES" | awk '{print $1}')
    if [ "$RES" != "0" ]; then
      D="$DST"/"$T"/diff-"${PNG##*-}"
      $COMPARE "$PNG" "$S" -highlight-color red "$D"
      echo "   Differences in $PNG and $S => $D"
      ERROR=1
    fi
  done
done

if [ $ERROR -eq 0 ]; then
  rm -rf "$DST"
fi

exit $ERROR
