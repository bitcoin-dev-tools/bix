INTERP="@interp@"

if [ -z "${PREVIOUS_RELEASES_DIR:-}" ]; then
  echo "error: PREVIOUS_RELEASES_DIR is not set" >&2
  exit 1
fi

if [ ! -f "$INTERP" ]; then
  echo "error: interpreter not found: $INTERP" >&2
  exit 1
fi

echo "Using interpreter: $INTERP"

count=0
while IFS= read -r -d '' bin; do
  if file "$bin" | grep -q 'ELF.*dynamically linked'; then
    patchelf --set-interpreter "$INTERP" "$bin"
    echo "  patched: ${bin#"$PREVIOUS_RELEASES_DIR"/}"
    count=$((count + 1))
  fi
done < <(find "$PREVIOUS_RELEASES_DIR" -path '*/bin/*' -type f -print0)

echo "Patched $count binaries."
