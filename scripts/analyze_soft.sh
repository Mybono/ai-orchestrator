#!/usr/bin/env bash
set -uo pipefail

# Script to check for software dependencies and offer installation

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print colored messages
print_message() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

print_message "${GREEN}--- Software Dependency Analysis ---${NC}"

# 1. Check for basic tools
for cmd in curl git; do
    if command_exists "$cmd"; then
        print_message "${GREEN}✓ $cmd is installed${NC}"
    else
        print_message "${RED}✗ $cmd is missing! Please install it first.${NC}"
        # We don't try to install curl/git as they are foundation tools
    fi
done

# 2. Check for jq
if command_exists jq; then
    print_message "${GREEN}✓ jq is installed${NC}"
else
    print_message "${YELLOW}! jq is missing (required for JSON processing)${NC}"
    read -p "Would you like to try installing jq now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists brew; then
                brew install jq
            else
                print_message "${RED}Homebrew not found. Please install jq manually.${NC}"
            fi
        elif command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command_exists dnf; then
            sudo dnf install -y jq
        else
            print_message "${RED}Unknown package manager. Please install jq manually.${NC}"
        fi
    fi
fi

# 3. Check for Ollama
if command_exists ollama; then
    print_message "${GREEN}✓ Ollama is installed${NC}"
else
    print_message "${YELLOW}! Ollama is missing (required for local AI agents)${NC}"
    read -p "Would you like to install Ollama now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists brew; then
                print_message "${GREEN}Installing Ollama via Homebrew...${NC}"
                brew install --cask ollama
            else
                print_message "${YELLOW}Downloading Ollama for macOS...${NC}"
                open https://ollama.com/download/Ollama-darwin.zip
                print_message "${GREEN}Please unzip and move Ollama to your Applications folder.${NC}"
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            print_message "${GREEN}Running official Ollama installation script...${NC}"
            curl -fsSL https://ollama.com/install.sh | sh
        else
            print_message "${RED}OS not recognized. Please install Ollama from https://ollama.com${NC}"
        fi
    fi
fi

print_message "${GREEN}--- Analysis complete ---${NC}"
