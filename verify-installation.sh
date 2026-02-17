#!/bin/bash
# Verify OpenClaw + NVIDIA Installation

echo "========================================"
echo "🔍 OpenClaw + NVIDIA Verification"
echo "========================================"
echo ""

# Check if OpenClaw is installed
if ! command -v openclaw &> /dev/null; then
    echo "❌ OpenClaw not found in PATH"
    exit 1
fi

echo "✓ OpenClaw found: $(which openclaw)"
echo "✓ Version: $(openclaw --version)"
echo ""

# Check NVIDIA configuration
echo "📋 NVIDIA Configuration:"
if [ -f ~/.openclaw/agents/main/agent/auth-profiles.json ]; then
    if grep -q "nvidia:default" ~/.openclaw/agents/main/agent/auth-profiles.json; then
        echo "  ✓ NVIDIA auth profile exists"
        if grep -q '"key":' ~/.openclaw/agents/main/agent/auth-profiles.json | grep -A2 "nvidia:default"; then
            echo "  ✓ API key is stored (hidden for security)"
        fi
    else
        echo "  ❌ NVIDIA auth profile not found"
    fi
else
    echo "  ❌ Auth profiles file not found"
fi

# Check models
echo ""
echo "🤖 NVIDIA Models:"
if [ -f ~/.openclaw/agents/main/agent/models.json ]; then
    MODEL_COUNT=$(grep -c '"id":' ~/.openclaw/agents/main/agent/models.json | grep nvidia || echo "0")
    if [ "$MODEL_COUNT" -ge 10 ]; then
        echo "  ✓ All 10 models configured"
        grep '"id":' ~/.openclaw/agents/main/agent/models.json | grep -E "(nvidia|meta|moonshotai|z-ai|thudm)" | sed 's/.*"id": "\([^"]*\)".*/    - \1/' | head -10
    else
        echo "  ⚠ Only some models configured ($MODEL_COUNT found)"
    fi
else
    echo "  ❌ Models file not found"
fi

# Check default model
echo ""
echo "🎯 Default Model:"
if [ -f ~/.openclaw/openclaw.json ]; then
    DEFAULT_MODEL=$(grep -o '"primary": "[^"]*"' ~/.openclaw/openclaw.json | head -1 | sed 's/.*": "\([^"]*\)".*/\1/')
    if [ -n "$DEFAULT_MODEL" ]; then
        echo "  ✓ Default: $DEFAULT_MODEL"
    else
        echo "  ⚠ No default model set"
    fi
else
    echo "  ❌ Config file not found"
fi

# Check MCP plugin
echo ""
echo "🔌 MCP Client Plugin:"
if [ -d /opt/openclaw/extensions/mcp-client ]; then
    echo "  ✓ Plugin installed"
    if [ -f /opt/openclaw/extensions/mcp-client/openclaw.plugin.json ]; then
        echo "  ✓ Plugin manifest exists"
    else
        echo "  ❌ Plugin manifest missing"
    fi
else
    echo "  ❌ Plugin not found"
fi

# Check Athena
echo ""
echo "🏛️ Athena Memory:"
if [ -d /opt/athena ]; then
    echo "  ✓ Athena installed at /opt/athena"
else
    echo "  ❌ Athena not found"
fi

echo ""
echo "========================================"
echo "🚀 Quick Test:"
echo "========================================"
echo "  openclaw send 'Hello' --model z-ai/glm5"
echo ""
echo "🎮 Interactive Setup:"
echo "  openclaw onboard"
echo "========================================"
