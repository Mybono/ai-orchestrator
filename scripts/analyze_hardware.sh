#!/usr/bin/env bash
set -euo pipefail

# Script to analyze system hardware and suggest the best Ollama models

echo "Starting hardware analysis..."

OS_TYPE=$(uname -s)
TOTAL_RAM_GB=0
HAS_DEDICATED_GPU=false
GPU_VRAM_GB=0
CHIP_TYPE="Unknown"

# 1. Detect RAM and CPU
if [[ "$OS_TYPE" == "Darwin" ]]; then
    # macOS
    RAM_BYTES=$(sysctl -n hw.memsize)
    TOTAL_RAM_GB=$(( RAM_BYTES / 1024 / 1024 / 1024 ))
    
    CHIP_NAME=$(sysctl -n machdep.cpu.brand_string)
    if [[ "$CHIP_NAME" == *"Apple"* ]]; then
        CHIP_TYPE="Apple Silicon (Unified Memory)"
        # On Apple Silicon, unified memory acts as VRAM
        HAS_DEDICATED_GPU=true
        GPU_VRAM_GB=$TOTAL_RAM_GB
    else
        CHIP_TYPE="Intel Mac"
    fi

elif [[ "$OS_TYPE" == "Linux" ]]; then
    # Linux
    if command -v awk >/dev/null; then
        RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        TOTAL_RAM_GB=$(( RAM_KB / 1024 / 1024 ))
    fi
    CHIP_TYPE=$(grep "model name" /proc/cpuinfo | head -n 1 | awk -F': ' '{print $2}')

    # Check for dedicated NVIDIA GPU
    if command -v nvidia-smi >/dev/null; then
        HAS_DEDICATED_GPU=true
        VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 || echo "0")
        GPU_VRAM_GB=$(( VRAM_MB / 1024 ))
    fi
fi

echo "OS: $OS_TYPE"
echo "CPU: $CHIP_TYPE"
echo "RAM: ${TOTAL_RAM_GB} GB"

if [ "$HAS_DEDICATED_GPU" = true ] && [[ "$OS_TYPE" != "Darwin" ]]; then
    echo "Dedicated GPU detected (VRAM: ~${GPU_VRAM_GB} GB)"
elif [[ "$OS_TYPE" == "Darwin" ]] && [ "$HAS_DEDICATED_GPU" = true ]; then
    echo "Unified Memory architecture, available for VRAM: up to ~$(($GPU_VRAM_GB * 3 / 4)) GB (depending on system load)"
else
    echo "No dedicated (NVIDIA) GPU detected. Inference will run on CPU or integrated graphics."
fi

echo "======================================"
echo "🤖 Recommended models for your system:"

# Target config file
CONFIG_FILE="$HOME/.claude/llm-config.json"

# Profile Logic
MODELS_TO_PULL=("nomic-embed-text")
CODER_MODEL=""
REVIEWER_MODEL=""
COMMIT_MODEL=""

if [[ "$OS_TYPE" == "Darwin" && "$HAS_DEDICATED_GPU" == true ]]; then
    if [ "$TOTAL_RAM_GB" -ge 64 ]; then
         echo "[ULTRA] RAM >= 64GB: 32B models are optimal."
         CODER_MODEL="qwen2.5-coder:32b"
         REVIEWER_MODEL="qwen2.5-coder:14b-instruct-q4_K_M"
         COMMIT_MODEL="qwen2.5-coder:7b"
    elif [ "$TOTAL_RAM_GB" -ge 32 ]; then
         echo "[HIGH] RAM >= 32GB: 14B-32B models are optimal."
         CODER_MODEL="qwen2.5-coder:14b-instruct-q4_K_M"
         REVIEWER_MODEL="qwen2.5-coder:7b"
         COMMIT_MODEL="qwen2.5-coder:7b"
    elif [ "$TOTAL_RAM_GB" -ge 16 ]; then
         echo "[MEDIUM] RAM 16GB-31GB: 7B-8B models are optimal."
         CODER_MODEL="qwen2.5-coder:7b"
         REVIEWER_MODEL="qwen2.5-coder:7b"
         COMMIT_MODEL="qwen2.5-coder:1.5b"
    else
         echo "[LOW] RAM < 16GB: Lightweight models (1.5B-3B) are recommended."
         CODER_MODEL="qwen2.5-coder:1.5b"
         REVIEWER_MODEL="qwen2.5-coder:1.5b"
         COMMIT_MODEL="qwen2.5-coder:1.5b"
    fi
else
    # Linux/Other
    if [ "$HAS_DEDICATED_GPU" = true ] && [ "$GPU_VRAM_GB" -ge 16 ]; then
         CODER_MODEL="qwen2.5-coder:14b-instruct-q4_K_M"
         REVIEWER_MODEL="qwen2.5-coder:7b"
         COMMIT_MODEL="qwen2.5-coder:7b"
    else
         CODER_MODEL="qwen2.5-coder:7b"
         REVIEWER_MODEL="qwen2.5-coder:7b"
         COMMIT_MODEL="qwen2.5-coder:1.5b"
    fi
fi

MODELS_TO_PULL+=("$CODER_MODEL" "$REVIEWER_MODEL" "$COMMIT_MODEL")
# Unique elements only
read -ra MODELS_TO_PULL <<< "$(echo "${MODELS_TO_PULL[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

echo "======================================"

# Check currently installed models
if command -v ollama >/dev/null; then
    INSTALLED_MODELS=$(ollama list | awk 'NR>1 {print $1}')
    echo "📋 Currently installed models:"
    echo "$INSTALLED_MODELS" | sed 's/^/  - /'
else
    echo "⚠️ Ollama not found."
    INSTALLED_MODELS=""
fi

echo "======================================"
echo "🤖 Recommended configuration for your hardware:"
echo "  - Coder:    $CODER_MODEL"
echo "  - Reviewer: $REVIEWER_MODEL"
echo "  - Commit:   $COMMIT_MODEL"

echo "======================================"
read -r -p "Apply these recommendations to $CONFIG_FILE? (y/N) " apply_cfg
if [[ "$apply_cfg" =~ ^[Yy]$ ]]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Initialize if missing
    if [[ ! -f "$CONFIG_FILE" ]]; then echo '{"models":{}}' > "$CONFIG_FILE"; fi

    # Update using jq
    tmp_cfg=$(mktemp)
    jq --arg coder "$CODER_MODEL" \
       --arg reviewer "$REVIEWER_MODEL" \
       --arg commit "$COMMIT_MODEL" \
       --arg embed "nomic-embed-text" \
       '.models.coder = $coder | .models.reviewer = $reviewer | .models.commit = $commit | .models.embedding = $embed' \
       "$CONFIG_FILE" > "$tmp_cfg" && mv "$tmp_cfg" "$CONFIG_FILE"
    
    echo "✅ Configuration updated."
fi

echo "======================================"
MODELS_TO_DOWNLOAD=()
for model in "${MODELS_TO_PULL[@]}"; do
    if echo "$INSTALLED_MODELS" | grep -qE "^${model}(:latest)?$"; then
        echo "✅ [Installed] $model"
    else
        echo "❌ [Missing]   $model"
        MODELS_TO_DOWNLOAD+=("$model")
    fi
done

if [ ${#MODELS_TO_DOWNLOAD[@]} -gt 0 ]; then
    echo "======================================"
    read -r -p "Download missing models now? (y/N) " dl_choice
    if [[ "$dl_choice" =~ ^[Yy]$ ]]; then
        for m in "${MODELS_TO_DOWNLOAD[@]}"; do
            ollama pull "$m"
        done
    fi
fi
