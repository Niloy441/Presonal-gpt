#!/bin/bash
# ============================================
# WormGPT (Local Ollama AI) - Fixed Script
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║   Local AI Setup - Ollama + Node.js     ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── Step 1: পুরনো process বন্ধ করো ──────────
echo -e "${GREEN}[1/10] Cleaning old processes...${NC}"
pkill -9 ollama 2>/dev/null || true
pkill -9 node 2>/dev/null || true
pkill -9 ngrok 2>/dev/null || true
tmux kill-session -t wormgpt 2>/dev/null || true
sleep 2

# ── Step 2: পুরনো Node.js সরাও ──────────────
echo -e "${GREEN}[2/10] Removing old Node.js...${NC}"
apt-get remove --purge -y nodejs npm 2>/dev/null || true
apt-get autoremove -y
apt-get clean

# ── Step 3: System update + dependencies ─────
echo -e "${GREEN}[3/10] Updating system...${NC}"
apt-get update -y
apt-get install -y \
  curl wget git unzip \
  zstd tmux lsof \
  net-tools ca-certificates \
  gnupg build-essential

# ── Step 4: Node.js 20 install ───────────────
echo -e "${GREEN}[4/10] Installing Node.js 20...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
echo "Node: $(node --version)"
echo "npm : $(npm --version)"

# ── Step 5: Repository clone ─────────────────
echo -e "${GREEN}[5/10] Cloning repository...${NC}"
cd /root
rm -rf WormGPT-2.0
git clone https://github.com/Niloy441/WormGPT-2.0.git
cd WormGPT-2.0

# ZIP extract
if [ -f "WormGPTForLinux.zip" ]; then
    unzip -o WormGPTForLinux.zip
else
    echo -e "${RED}❌ WormGPTForLinux.zip পাওয়া যায়নি!${NC}"
    exit 1
fi

# Extracted folder খুঁজে বের করো
EXTRACTED_DIR=$(ls -d */ 2>/dev/null | grep -i "gpt_linux" | head -1)
if [ -z "$EXTRACTED_DIR" ]; then
    # যেকোনো folder নাও
    EXTRACTED_DIR=$(ls -d */ 2>/dev/null | head -1)
fi
if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${RED}❌ Extracted folder পাওয়া যায়নি!${NC}"
    ls -la
    exit 1
fi
EXTRACTED_DIR="${EXTRACTED_DIR%/}"
echo -e "${GREEN}✅ Folder: $EXTRACTED_DIR${NC}"

# ── Step 6: Node dependencies install ────────
echo -e "${GREEN}[6/10] Installing Node dependencies...${NC}"

# Server
if [ -d "$EXTRACTED_DIR/server" ]; then
    cd "/root/WormGPT-2.0/$EXTRACTED_DIR/server"
    rm -rf node_modules package-lock.json
    npm install
else
    echo -e "${RED}❌ server folder নেই!${NC}"
    exit 1
fi

# App (frontend)
if [ -d "/root/WormGPT-2.0/$EXTRACTED_DIR/app" ]; then
    cd "/root/WormGPT-2.0/$EXTRACTED_DIR/app"
    rm -rf node_modules package-lock.json
    npm install
    npm run build 2>/dev/null || echo "Build skip করা হলো"
fi

# ── Step 7: Ollama install ────────────────────
echo -e "${GREEN}[7/10] Installing Ollama...${NC}"
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo "Ollama আগে থেকেই আছে"
fi

# ── Step 8: ngrok install ─────────────────────
echo -e "${GREEN}[8/10] Installing ngrok...${NC}"
if ! command -v ngrok &>/dev/null; then
    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
      | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" \
      | tee /etc/apt/sources.list.d/ngrok.list
    apt-get update && apt-get install -y ngrok
else
    echo "ngrok আগে থেকেই আছে"
fi

# ── Step 9: Helper scripts তৈরি করো ──────────
echo -e "${GREEN}[9/10] Creating helper scripts...${NC}"

SERVER_PATH="/root/WormGPT-2.0/$EXTRACTED_DIR/server"

# start script
cat > /root/start_wormgpt.sh << INNER
#!/bin/bash
pkill -9 ollama 2>/dev/null || true
pkill -9 node 2>/dev/null || true
sleep 2

# Ollama চালু
ollama serve > /tmp/ollama.log 2>&1 &
echo "Ollama চালু হচ্ছে..."
sleep 8

# Model pull (না থাকলে)
ollama pull llama3.2:1b

# Server চালু
cd $SERVER_PATH
OLLAMA_HOST=http://localhost:11434 node index.js
INNER
chmod +x /root/start_wormgpt.sh

# run (tmux background)
cat > /root/run_wormgpt.sh << 'INNER'
#!/bin/bash
pkill -9 ollama 2>/dev/null || true
pkill -9 node 2>/dev/null || true
tmux kill-session -t wormgpt 2>/dev/null || true
sleep 2
tmux new-session -d -s wormgpt '/root/start_wormgpt.sh'
echo "✅ Background-এ চলছে"
echo "📌 Live দেখতে: tmux attach -t wormgpt"
INNER
chmod +x /root/run_wormgpt.sh

# tunnel
cat > /root/tunnel.sh << 'INNER'
#!/bin/bash
ngrok http 8080
INNER
chmod +x /root/tunnel.sh

# status
cat > /root/status.sh << 'INNER'
#!/bin/bash
echo "=== Status ==="
echo -n "Ollama : "
curl -s http://localhost:11434/api/tags >/dev/null 2>&1 \
  && echo "✅ চলছে" || echo "❌ বন্ধ"
echo -n "Server : "
curl -s http://localhost:8080 >/dev/null 2>&1 \
  && echo "✅ চলছে" || echo "❌ বন্ধ"
echo -n "ngrok  : "
curl -s http://localhost:4040/api/tunnels 2>/dev/null \
  | grep -o 'https://[^"]*\.ngrok-free\.app' \
  || echo "বন্ধ"
INNER
chmod +x /root/status.sh

# kill
cat > /root/kill_wormgpt.sh << 'INNER'
#!/bin/bash
pkill -9 ollama 2>/dev/null || true
pkill -9 node 2>/dev/null || true
pkill -9 ngrok 2>/dev/null || true
tmux kill-session -t wormgpt 2>/dev/null || true
echo "✅ সব বন্ধ"
INNER
chmod +x /root/kill_wormgpt.sh

# URL getter
cat > /root/get_url.sh << 'INNER'
#!/bin/bash
URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null \
  | grep -o 'https://[^"]*\.ngrok-free\.app')
if [ -n "$URL" ]; then
    echo "🌐 Link: $URL"
    echo "🔑 Password: Realnojokepplwazy1234"
else
    echo "❌ ngrok চালু নেই। চালাও: /root/tunnel.sh"
fi
INNER
chmod +x /root/get_url.sh

# ── Step 10: সব চালু করো ─────────────────────
echo -e "${GREEN}[10/10] Starting services...${NC}"
/root/run_wormgpt.sh

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║         ✅ Setup সম্পূর্ণ!              ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}এখন আলাদা terminal-এ চালাও:${NC}"
echo -e "${GREEN}  /root/tunnel.sh${NC}"
echo ""
echo -e "${YELLOW}Link পেতে:${NC}"
echo -e "${GREEN}  /root/get_url.sh${NC}"
echo ""
echo "📋 অন্যান্য কমান্ড:"
echo "  /root/status.sh       → status দেখো"
echo "  /root/kill_wormgpt.sh → সব বন্ধ করো"
echo "  /root/run_wormgpt.sh  → পুনরায় চালু করো"
echo "  tmux attach -t wormgpt → live output"
