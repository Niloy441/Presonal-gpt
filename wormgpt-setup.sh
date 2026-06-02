cat > /root/wormgpt_oneclick.sh << 'EOF'
#!/bin/bash
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
echo -e "${CYAN}=========================================="
echo "🚀 WormGPT Full Auto-Setup (One Terminal)"
echo -e "==========================================${NC}"

# 1. Dependencies
echo -e "${GREEN}[1/7] Installing dependencies...${NC}"
apt-get update -y && apt-get install -y curl wget git nodejs npm docker.io unzip

# 2. Clone & unzip
echo -e "${GREEN}[2/7] Cloning repository...${NC}"
cd /root
rm -rf WormGPT-2.0
git clone https://github.com/Niloy441/WormGPT-2.0.git
cd WormGPT-2.0
unzip -o WormGPTForLinux.zip
EXTRACTED_DIR=$(ls -d *gpt_linux_v2 2>/dev/null | head -1)
if [ -z "$EXTRACTED_DIR" ]; then echo -e "${RED}Extraction failed${NC}"; exit 1; fi

# 3. Install Node deps & build frontend
echo -e "${GREEN}[3/7] Installing Node modules & building frontend...${NC}"
cd "$EXTRACTED_DIR/server" && npm install --silent
cd ../app && npm install --silent && npm run build --silent || true

# 4. Docker Ollama (CPU)
echo -e "${GREEN}[4/7] Starting Ollama...${NC}"
docker stop ollama-cpu 2>/dev/null || true
docker rm ollama-cpu 2>/dev/null || true
docker run -d -p 11434:11434 -v ollama:/root/.ollama --name ollama-cpu ollama/ollama
sleep 5
echo -e "${GREEN}[5/7] Pulling AI model (llama3.2:1b)...${NC}"
docker exec ollama-cpu ollama pull llama3.2:1b

# 5. Install ngrok
echo -e "${GREEN}[6/7] Installing ngrok...${NC}"
cd /root
wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
unzip -o ngrok-stable-linux-amd64.zip
chmod +x ngrok

# 6. Start WormGPT server in background
echo -e "${GREEN}[7/7] Starting services in background...${NC}"
cd /root/WormGPT-2.0/$EXTRACTED_DIR/server
OLLAMA_HOST=http://localhost:11434 nohup node index.js > /tmp/wormgpt.log 2>&1 &
sleep 3

# 7. Start ngrok tunnel in background and capture URL
cd /root
nohup ./ngrok http 8080 > /tmp/ngrok.log 2>&1 &
sleep 6

# 8. Display public URL
echo -e "${CYAN}=========================================="
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "${CYAN}=========================================="
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*\.ngrok[^"]*' | head -1)
if [ -n "$NGROK_URL" ]; then
    echo -e "${GREEN}🌐 Public URL: ${YELLOW}$NGROK_URL${NC}"
else
    echo -e "${RED}⚠️  ngrok URL not ready yet. Run: curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*\.ngrok[^"]*'${NC}"
fi
echo -e "${CYAN}🔑 Password: ${YELLOW}Realnojokepplwazy1234${NC}"
echo -e "${CYAN}📋 Server log: ${YELLOW}tail -f /tmp/wormgpt.log${NC}"
echo -e "${CYAN}📋 ngrok log: ${YELLOW}tail -f /tmp/ngrok.log${NC}"
echo -e "${GREEN}All services running in background. Close terminal? Services keep running.${NC}"
echo -e "${YELLOW}To stop: pkill -f 'node index.js' && pkill -f ngrok && docker stop ollama-cpu${NC}"
EOF

chmod +x /root/wormgpt_oneclick.sh && /root/wormgpt_oneclick.sh
