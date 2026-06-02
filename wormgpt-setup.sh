cat > /root/ultimate_install.sh << 'EOF'
#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     🚀 WormGPT Ultimate Installer - Complete Setup      ║"
echo "║         No Reset | No Error | One Click Ready           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# Step 1: Clean old installations
# ============================================
echo -e "${GREEN}[1/15] Cleaning old installations...${NC}"
pkill -9 ollama 2>/dev/null || true
pkill -9 node 2>/dev/null || true
pkill -9 ngrok 2>/dev/null || true
tmux kill-session -t wormgpt 2>/dev/null || true

# ============================================
# Step 2: Remove old Node.js
# ============================================
echo -e "${GREEN}[2/15] Removing old Node.js...${NC}"
dpkg --remove --force-remove-reinstreq nodejs 2>/dev/null || true
dpkg --remove --force-remove-reinstreq libnode-dev 2>/dev/null || true
dpkg --remove --force-remove-reinstreq libnode-devel 2>/dev/null || true
apt-get autoremove -y
apt-get clean

# ============================================
# Step 3: Update system & install dependencies
# ============================================
echo -e "${GREEN}[3/15] Updating system and installing dependencies...${NC}"
apt-get update -y
apt-get install -y curl wget git npm unzip zstd tmux lsof net-tools

# ============================================
# Step 4: Install Node.js 20
# ============================================
echo -e "${GREEN}[4/15] Installing Node.js 20...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ============================================
# Step 5: Clone WormGPT repository
# ============================================
echo -e "${GREEN}[5/15] Cloning WormGPT repository...${NC}"
cd /root
rm -rf WormGPT-2.0
git clone https://github.com/Niloy441/WormGPT-2.0.git
cd WormGPT-2.0
unzip -o WormGPTForLinux.zip

# Find extracted folder
EXTRACTED_DIR=$(ls -d *gpt_linux_v2 2>/dev/null | head -1)
if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${RED}Extracted folder not found!${NC}"
    exit 1
fi
echo -e "${GREEN}Extracted folder: $EXTRACTED_DIR${NC}"

# ============================================
# Step 6: Install Node dependencies
# ============================================
echo -e "${GREEN}[6/15] Installing Node dependencies...${NC}"
cd "$EXTRACTED_DIR/server"
npm install --silent
cd ../app
npm install --silent
npm run build --silent || true

# ============================================
# Step 7: Install Ollama
# ============================================
echo -e "${GREEN}[7/15] Installing Ollama...${NC}"
curl -fsSL https://ollama.com/install.sh | sh

# ============================================
# Step 8: Install ngrok
# ============================================
echo -e "${GREEN}[8/15] Installing ngrok...${NC}"
cd /root
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" | tee /etc/apt/sources.list.d/ngrok.list
apt-get update && apt-get install -y ngrok

# ============================================
# Step 9: Create start script
# ============================================
echo -e "${GREEN}[9/15] Creating start script...${NC}"
cat > /root/start_wormgpt.sh << 'INNER'
#!/bin/bash
pkill -9 ollama 2>/dev/null
pkill -9 node 2>/dev/null
ollama serve > /tmp/ollama.log 2>&1 &
sleep 5
ollama pull llama3.2:1b
cd /root/WormGPT-2.0/$(ls /root/WormGPT-2.0 | grep gpt_linux_v2)/server
OLLAMA_HOST=http://localhost:11434 node index.js
INNER
chmod +x /root/start_wormgpt.sh

# ============================================
# Step 10: Create ngrok tunnel script
# ============================================
echo -e "${GREEN}[10/15] Creating ngrok tunnel script...${NC}"
cat > /root/tunnel.sh << 'INNER'
#!/bin/bash
ngrok http 8080
INNER
chmod +x /root/tunnel.sh

# ============================================
# Step 11: Create run script (tmux background)
# ============================================
echo -e "${GREEN}[11/15] Creating run script...${NC}"
cat > /root/run_wormgpt.sh << 'INNER'
#!/bin/bash
pkill -9 ollama 2>/dev/null
pkill -9 node 2>/dev/null
tmux kill-session -t wormgpt 2>/dev/null
tmux new-session -d -s wormgpt '/root/start_wormgpt.sh'
sleep 5
echo "✅ WormGPT সার্ভার চালু আছে (TMUX সেশনে)"
echo "📌 টিএমইউএক্স সেশন দেখতে: tmux attach -t wormgpt"
INNER
chmod +x /root/run_wormgpt.sh

# ============================================
# Step 12: Create kill script
# ============================================
echo -e "${GREEN}[12/15] Creating kill script...${NC}"
cat > /root/kill_wormgpt.sh << 'INNER'
#!/bin/bash
pkill -9 ollama 2>/dev/null
pkill -9 node 2>/dev/null
pkill -9 ngrok 2>/dev/null
tmux kill-session -t wormgpt 2>/dev/null
echo "✅ সব প্রক্রিয়া বন্ধ করা হয়েছে।"
INNER
chmod +x /root/kill_wormgpt.sh

# ============================================
# Step 13: Create status check script
# ============================================
echo -e "${GREEN}[13/15] Creating status check script...${NC}"
cat > /root/status.sh << 'INNER'
#!/bin/bash
echo "=== প্রক্রিয়া স্ট্যাটাস ==="
echo -n "Ollama: "
curl -s http://localhost:11434/api/tags >/dev/null && echo "✅ চলছে" || echo "❌ বন্ধ"
echo -n "WormGPT: "
curl -s http://localhost:8080 >/dev/null && echo "✅ চলছে" || echo "❌ বন্ধ"
echo -n "ngrok লিংক: "
curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o 'https://[^\"]*\.ngrok-free\.dev' || echo "নাই"
INNER
chmod +x /root/status.sh

# ============================================
# Step 14: Create ngrok URL fetcher
# ============================================
echo -e "${GREEN}[14/15] Creating get_url script...${NC}"
cat > /root/get_url.sh << 'INNER'
#!/bin/bash
URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o 'https://[^\"]*\.ngrok-free\.dev')
if [ -n "$URL" ]; then
    echo "🌐 আপনার WormGPT লিংক: $URL"
    echo "🔑 পাসওয়ার্ড: Realnojokepplwazy1234"
else
    echo "❌ ngrok লিংক পাওয়া যায়নি। নিশ্চিত করুন ngrok চালু আছে।"
    echo "📌 ngrok চালু করতে: ngrok http 8080"
fi
INNER
chmod +x /root/get_url.sh

# ============================================
# Step 15: Start everything
# ============================================
echo -e "${GREEN}[15/15] Starting all services...${NC}"
/root/run_wormgpt.sh

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              ✅ ইনস্টলেশন সম্পূর্ণ!                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

sleep 5

echo -e "${YELLOW}📌 এখন আলাদা টার্মিনালে ngrok চালু করুন:${NC}"
echo -e "${GREEN}   /root/tunnel.sh${NC}"
echo ""
echo -e "${YELLOW}📌 ngrok চালু হওয়ার পর লিংক পেতে:${NC}"
echo -e "${GREEN}   /root/get_url.sh${NC}"
echo ""
echo -e "${GREEN}🔑 পাসওয়ার্ড: Realnojokepplwazy1234${NC}"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📋 অন্যান্য কমান্ড:${NC}"
echo -e "   /root/status.sh      - স্ট্যাটাস দেখতে"
echo -e "   /root/kill_wormgpt.sh - সব বন্ধ করতে"
echo -e "   /root/run_wormgpt.sh  - পুনরায় চালু করতে"
echo -e "   tmux attach -t wormgpt - লাইভ আউটপুট দেখতে"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

# Auto-start ngrok提示
echo ""
echo -e "${YELLOW}⚡ দ্রুত ngrok চালু করতে এখনই এই কমান্ড দিন (অন্য টার্মিনালে):${NC}"
echo -e "${GREEN}   ngrok http 8080${NC}"

EOF

chmod +x /root/ultimate_install.sh && /root/ultimate_install.sh
