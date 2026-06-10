#!/usr/bin/env bash

# ==============================================================================
# INSTRUCTIONS FOR MANUAL ACTIVATION:
# If you are installing or copying this file manually, make it executable with:
#     chmod +x install_tutor.sh
# ...and run it with:
#     ./install_tutor.sh
# ==============================================================================

# Color codes for clean output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Starting AI Tutor Installation...${NC}"

# 1. Create target directory if it doesn't exist
TARGET_DIR="$HOME/.local/bin"
mkdir -p "$TARGET_DIR"

# 2. Write the tutor Python script
echo -e "${YELLOW}📝 Writing tutor backend to $TARGET_DIR/tutor...${NC}"
cat << 'EOF' > "$TARGET_DIR/tutor"
#!/usr/bin/python3
import os
import sys
import sqlite3
import requests
from pathlib import Path

# Check for help flags or an empty query right at the start
user_question = " ".join(sys.argv[1:]).strip()
if not user_question or user_question in ['-h', '--help', 'man']:
    print("SHOW_HELP_GUIDE")
    sys.exit(0)

API_KEY = os.getenv("GEMINI_API_KEY") 
if not API_KEY:
    print("\033[31mError: GEMINI_API_KEY environment variable not found.\033[0m")
    print("Please add 'export GEMINI_API_KEY=\"your_key_here\"' to your ~/.bashrc")
    sys.exit(1)

def get_recent_history(limit=5):
    db_path = Path.home() / ".local" / "share" / "atuin" / "history.db"
    if not db_path.exists():
        return "No local command history found."
    
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT command, exit_status 
            FROM history 
            ORDER BY timestamp DESC 
            LIMIT ?
        """, (limit,))
        rows = cursor.fetchall()
        conn.close()
        
        rows.reverse()
        
        context_lines = []
        for cmd, status in rows:
            if cmd.startswith("tutor ") or cmd.startswith("? "):
                continue
            status_text = "Success" if status == 0 else f"Failed (Exit Code {status})"
            context_lines.append(f"Command: {cmd} -> Status: {status_text}")
            
        return "\n".join(context_lines)
    except Exception as e:
        return f"Could not read history: {str(e)}"

terminal_history = get_recent_history(6)

system_instruction = (
    "You are a minimal, ultra-concise Linux command helper and tutor.\n\n"
    "YOUR PRIMARY JOB:\n"
    "Convert the user's natural language request into the exact Linux command they need.\n\n"
    "YOUR SECONDARY JOB:\n"
    "Look at the provided terminal history. If their question is clearly about an error or a "
    "command that just failed, diagnose it and provide the corrected command.\n\n"
    "FORMATTING RULES:\n"
    "1. Start immediately with the exact command inside a markdown code block. No intro text.\n"
    "2. Below the code block, add a single sentence explaining either what the command does, "
    "or why the previous error occurred. Keep it incredibly brief."
)

full_prompt = f"{system_instruction}\n\n--- RECENT TERMINAL HISTORY ---\n{terminal_history}\n-------------------------------\n\nUser Request: {user_question}"

url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={API_KEY}"
headers = {"Content-Type": "application/json"}
payload = {"contents": [{"parts": [{"text": full_prompt}]}]}

try:
    print("\033[33m🤖 Consulting the archives...\033[0m", end="\r")
    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()
    reply = response.json()['candidates'][0]['content']['parts'][0]['text']
    print(" " * 30, end="\r") 
    print(reply.strip() + "\n")
except Exception as e:
    print(f"\r\033[31mError communicating with tutor engine:\033[0m {e}")
EOF

# 3. Make the backend executable automatically via installer
chmod +x "$TARGET_DIR/tutor"

# 4. Patch ~/.bashrc with the safe function syntax and the help-intercept logic
echo -e "${YELLOW}⚙️  Configuring Bash shortcuts in ~/.bashrc...${NC}"

# We define the echo block inside a clean bash function so both the installer 
# and the runtime shell function can invoke it natively.
if ! grep -q "function tutor_help" "$HOME/.bashrc"; then
    cat << 'EOF' >> "$HOME/.bashrc"

# --- AI Terminal Tutor Configuration ---
export PATH="$HOME/.local/bin:$PATH"

function tutor_help {
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'

    echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
    echo -e "${GREEN}${BOLD}🤖 AI TERMINAL TUTOR USAGE GUIDE${NC}"
    echo -e "${GREEN}${BOLD}======================================================================${NC}\n"

    echo -e "${CYAN}${BOLD}👉 STEP 1: LOAD THE NEW CONFIGURATION${NC}"
    echo -e "To lock in changes without opening a new window, run:"
    echo -e "   ${YELLOW}source ~/.bashrc${NC}\n"

    echo -e "${CYAN}${BOLD}👉 STEP 2: SET UP YOUR API KEY${NC}"
    echo -e "Make sure your Gemini API key is exported in your environment. You can add this"
    echo -e "to your ${YELLOW}~/.bashrc${NC} permanently:"
    echo -e "   ${YELLOW}export GEMINI_API_KEY=\"your_actual_api_key_here\"${NC}\n"

    echo -e "${CYAN}${BOLD}👉 STEP 3: USAGE EXAMPLES${NC}"
    echo -e "You can now use the ${GREEN}?${NC} character at the start of any command to ask a question."
    echo -e "   ${BOLD}\$ ? find files over 50MB in the current directory${NC}"
    echo -e "   ${BOLD}\$ ? how to compress a directory into a tar archive${NC}\n"

    echo -e "${CYAN}${BOLD}👉 STEP 4: HELP COMMANDS${NC}"
    echo -e "To bring up this guide again at any time, simply type any of the following:"
    echo -e "   ${YELLOW}\$ ?${NC}"
    echo -e "   ${YELLOW}\$ ? -h${NC}"
    echo -e "   ${YELLOW}\$ ? --help${NC}"
    echo -e "   ${YELLOW}\$ ? man${NC}\n"

    echo -e "${CYAN}${BOLD}⚠️  CRITICAL BASH SAFETY RULE:${NC}"
    echo -e "Because ${RED}?${NC} is a special character, contractions with apostrophes (like ${RED}didn't${NC} or ${RED}can't${NC})"
    echo -e "will cause Bash to open an incomplete single-quote multi-line prompt. Always wrap your"
    echo -e "complex or punctuated questions in double quotes to bypass this:"
    echo -e "   ${GREEN}Correct:${NC}   ${YELLOW}\$ ? \"why didn't my last command execute?\"${NC}"
    echo -e "   ${GREEN}Correct:${NC}   ${YELLOW}\$ ? why did my chmod command fail${NC} (No apostrophes used)"
    echo -e "   ${RED}Incorrect:${NC} ${YELLOW}\$ ? why didn't it work${NC} (Will lock the terminal prompt)\n"

    echo -e "${GREEN}${BOLD}======================================================================${NC}"
}

function ? {
    # Run the Python script and capture its output
    local output
    output=$(/home/thomas/.local/bin/tutor "$@")
    
    # If the Python script detects a help flag, it prints "SHOW_HELP_GUIDE"
    if [ "$output" = "SHOW_HELP_GUIDE" ]; then
        tutor_help
    else
        echo "$output"
    |
}
EOF
    # Quick structural fix for the function layout output piping
    sed -i 's/    |/    fi/g' "$HOME/.bashrc"
    echo -e "${GREEN}✅ Added shortcut and help architecture to ~/.bashrc!${NC}"
else
    echo -e "${YELLOW}ℹ️  Shortcut configuration already exists in ~/.bashrc, skipping duplication.${NC}"
fi

# 5. Check dependencies
echo -e "${YELLOW}🔍 Verifying Python package dependencies...${NC}"
if ! python3 -c "import requests" 2>/dev/null; then
    echo -e "${YELLOW}📦 'requests' package missing. Attempting apt installation...${NC}"
    sudo apt update && sudo apt install python3-requests -y
else
    echo -e "${GREEN}✅ Python dependencies verified.${NC}"
fi

# 6. Display Interactive Onboarding Guide via Echo Blocks immediately upon install
source "$HOME/.bashrc" 2>/dev/null
if [ -n "$(type -t tutor_help)" ]; then
    tutor_help
fi
