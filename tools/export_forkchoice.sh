#!/bin/bash

# Export beacon chain fork choice as a block tree visualization
# Usage: export_forkchoice.sh [endpoint] [output_dir]

ENDPOINT="${1:-http://localhost:7777}"
OUT_DIR="${2:-./logs/forkchoice}"

mkdir -p "$OUT_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
JSON_FILE="$OUT_DIR/fork-$TIMESTAMP.json"
DOT_FILE="$OUT_DIR/fork-$TIMESTAMP.dot"
PNG_FILE="$OUT_DIR/fork-$TIMESTAMP.png"

# Fetch fork choice data
curl -s "$ENDPOINT/eth/v1/debug/fork_choice" > "$JSON_FILE"

# Extract head root for highlighting
HEAD_ROOT=$(jq -r '.extra_data.head_root // empty' "$JSON_FILE")

# Generate DOT graph
{
  echo "digraph BlockTree {"
  echo "  rankdir=TB;"
  echo "  node [shape=record, fontsize=9];"
  echo "  edge [fontsize=8];"
  
  # Create edges: parent -> child
  jq -r '.fork_choice_nodes[] | 
    select(.parent_root != "0x0000000000000000000000000000000000000000000000000000000000000000") |
    "  \"" + .parent_root + "\" -> \"" + .block_root + "\";"' "$JSON_FILE"
  
  # Create node labels with slot and short hash
  jq -r '.fork_choice_nodes[] | 
    "  \"" + .block_root + "\" [label=\"Slot " + .slot + "\\n" + (.block_root[0:8]) + "…\"];"' "$JSON_FILE"
  
  # Highlight head node
  if [ -n "$HEAD_ROOT" ]; then
    echo "  \"$HEAD_ROOT\" [fillcolor=lightgreen, style=filled];"
  fi
  
  # Highlight genesis (slot 0)
  jq -r '.fork_choice_nodes[] | select(.slot == "0") | 
    "  \"" + .block_root + "\" [fillcolor=lightblue, style=filled];"' "$JSON_FILE"
    
  echo "}"
} > "$DOT_FILE"

# Render PNG if dot is available
if command -v dot >/dev/null; then
  dot -Tpng "$DOT_FILE" -o "$PNG_FILE"
  echo "Block tree exported: $PNG_FILE"
else
  echo "Block tree DOT file: $DOT_FILE (install graphviz to render PNG)"
fi