#!/usr/bin/env bash
set -euo pipefail

ATOM_APP="/Applications/Atom.app"
VSCODE_BUNDLE_ID="com.microsoft.VSCode"

if ! command -v duti >/dev/null 2>&1; then
  echo "Ошибка: duti не установлен. Установи: brew install duti"
  exit 1
fi

if [ ! -d "$ATOM_APP" ]; then
  echo "Ошибка: не найден $ATOM_APP"
  exit 1
fi

tmp_exts="$(mktemp)"
tmp_atom="$(mktemp)"

cleanup() {
  rm -f "$tmp_exts" "$tmp_atom"
}
trap cleanup EXIT

plutil -p "$ATOM_APP/Contents/Info.plist" \
  | grep '=> "' \
  | sed -n 's/.*=> "\(.*\)"/\1/p' \
  | sort -u > "$tmp_exts"

echo "Проверяю расширения, которые сейчас по умолчанию открываются через Atom..."
echo

while IFS= read -r ext; do
  [ -z "$ext" ] && continue

  out="$(duti -x "$ext" 2>/dev/null || true)"

  if echo "$out" | grep -qiE 'com\.github\.atom|Atom\.app'; then
    echo "$ext" >> "$tmp_atom"
    echo ".$ext"
    echo "$out"
    echo
  fi
done < "$tmp_exts"

if [ ! -s "$tmp_atom" ]; then
  echo "Расширений, привязанных к Atom, не найдено."
  exit 0
fi

echo "Найдены расширения, сейчас привязанные к Atom:"
tr '\n' ' ' < "$tmp_atom"
echo
echo

read -r -p "Переключить их все на VSCode? [y/N] " answer

case "$answer" in
  y|Y|yes|YES)
    while IFS= read -r ext; do
      [ -z "$ext" ] && continue
      echo "Переключаю .$ext -> $VSCODE_BUNDLE_ID"
      duti -s "$VSCODE_BUNDLE_ID" ".$ext" all || true
    done < "$tmp_atom"

    echo
    echo "Готово."
    echo "Проверка нескольких расширений:"
    while IFS= read -r ext; do
      [ -z "$ext" ] && continue
      echo "===== .$ext ====="
      duti -x "$ext" 2>/dev/null || true
      echo
    done < <(head -n 10 "$tmp_atom")
    ;;
  *)
    echo "Ничего не менял."
    ;;
esac
