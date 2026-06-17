#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本！"
  exit 1
fi

echo "=================================================="
echo "    Linux 系统一键后置安全加固脚本 (终极通刷版)    "
echo "=================================================="

# 1. 交互获取公钥
read -p "👉 请粘贴你的 SSH 公钥 (例如 ssh-ed25519 ...): " SSH_KEY
if [ -z "$SSH_KEY" ]; then
    echo "❌ 错误：公钥不能为空！"
    exit 1
fi

# 2. 基础工具安装
echo -e "\n🔄 正在更新系统并安装基础工具 (unzip, curl, vim)..."
apt update && apt install unzip curl vim wget -y

# 3. 配置 SSH 密钥
echo -e "\n🔑 正在配置 SSH 公钥..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$SSH_KEY" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 4. SSH 核心安全加固（精确清洗 + 统一归一）
echo -e "\n🛡️ 正在进行 SSH 安全加固..."

SSHD_CONFIG="/etc/ssh/sshd_config"

# 4a. 精确清洗主配置文件（把这台机器上的 PermitRootLogin yes 连根拔起）
if [ -f "$SSHD_CONFIG" ]; then
    echo "📝 正在净化 $SSHD_CONFIG 主配置文件..."
    sed -i '/^[[:space:]#]*PasswordAuthentication[[:space:]]/Id' "$SSHD_CONFIG"
    sed -i '/^[[:space:]#]*PermitRootLogin[[:space:]]/Id' "$SSHD_CONFIG"
    sed -i '/^[[:space:]#]*PubkeyAuthentication[[:space:]]/Id' "$SSHD_CONFIG"
fi

# 4b. 根据系统架构走不同的写入逻辑
if [ -d /etc/ssh/sshd_config.d ]; then
    echo "🧹 检测到 sshd_config.d 目录，正在清理所有残余配置..."
    # 彻底荡平 50-cloud-init 和 60-cloudimg 等所有干扰项
    rm -f /etc/ssh/sshd_config.d/*.conf
    
    echo "📝 正在创建标准化的 99-security.conf..."
    cat << 'EOF' > /etc/ssh/sshd_config.d/99-security.conf
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin prohibit-password
EOF
    echo "✅ 子目录配置成功！"
else
    echo "📝 正在向主配置文件追加标准安全配置..."
    echo "" >> "$SSHD_CONFIG"
    echo "# ===== 由自动化脚本添加的安全配置 =====" >> "$SSHD_CONFIG"
    echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
    echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
    echo "PermitRootLogin prohibit-password" >> "$SSHD_CONFIG"
    echo "✅ 主目录配置成功！"
fi

# 5. 重启 SSH 服务使其生效
echo -e "\n🔄 正在重启 SSH 服务..."
systemctl daemon-reload
if systemctl is-active --quiet ssh; then
    systemctl restart ssh
elif systemctl is-active --quiet sshd; then
    systemctl restart sshd
else
    service ssh restart || service sshd restart
fi

echo "=================================================="
echo "🎉 脚本执行完毕！系统已开启纯密钥登录。"
echo "⚠️  【防失联警告】：请先不要关闭当前 SSH 窗口！"
echo "👉 请打开一个新终端窗口，尝试用密钥连接，确保能正常登录。"
echo "=================================================="