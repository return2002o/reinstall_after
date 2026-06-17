#!/bin/bash

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本！"
  exit 1
fi

echo "=================================================="
echo "    Linux 一键安全加固脚本 V4 (防爆破防扫描版)     "
echo "=================================================="

# 1. 交互获取公钥
read -p "👉 请粘贴你的 SSH 公钥 (例如 ssh-ed25519 ...): " SSH_KEY
if [ -z "$SSH_KEY" ]; then
    echo "❌ 错误：公钥不能为空！"
    exit 1
fi

# 2. 基础工具及安全软件安装
echo -e "\n🔄 正在安装基础工具及安全软件 (Fail2ban, UFW)..."
apt update && apt install unzip curl vim wget fail2ban ufw -y

# 3. 配置 SSH 密钥
echo -e "\n🔑 正在配置 SSH 公钥..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$SSH_KEY" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 4. SSH 核心安全加固
echo -e "\n🛡️ 正在进行 SSH 内部净化..."
SSHD_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSHD_CONFIG" ]; then
    sed -i '/^[[:space:]#]*PasswordAuthentication[[:space:]]/Id' "$SSHD_CONFIG"
    sed -i '/^[[:space:]#]*PermitRootLogin[[:space:]]/Id' "$SSHD_CONFIG"
    sed -i '/^[[:space:]#]*PubkeyAuthentication[[:space:]]/Id' "$SSHD_CONFIG"
fi

if [ -d /etc/ssh/sshd_config.d ]; then
    rm -f /etc/ssh/sshd_config.d/*.conf
    cat << 'EOF' > /etc/ssh/sshd_config.d/99-security.conf
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin prohibit-password
EOF
else
    echo "" >> "$SSHD_CONFIG"
    echo "# ===== 由自动化脚本添加的安全配置 =====" >> "$SSHD_CONFIG"
    echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
    echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
    echo "PermitRootLogin prohibit-password" >> "$SSHD_CONFIG"
fi

# 5. 配置 Fail2ban (多次尝试失败暂封 IP)
echo -e "\n🤖 正在配置 Fail2ban 动态封禁策略..."
cat << 'EOF' > /etc/fail2ban/jail.local
[DEFAULT]
# 发现攻击的时间窗口：10分钟
findtime = 10m
# 封禁时间：1小时 (可改为 24h 或 永久 -1)
bantime = 1h
# 最大尝试次数：3次
maxretry = 3
# 封禁动作：使用 iptables 封禁所有端口
banaction = iptables-multiport

[sshd]
enabled = true
port = ssh
filter = sshd
backend = systemd
EOF

# 重启 Fail2ban 使其生效
systemctl daemon-reload
systemctl enable fail2ban
systemctl restart fail2ban
echo "✅ Fail2ban 配置成功：10分钟内失败3次即封禁1小时！"

# 6. 配置 UFW 防火墙 (限流防恶意刷连接)
echo -e "\n🧱 正在配置 UFW 防火墙限流..."
# 首先防锁死：必须先允许 SSH
ufw allow ssh
# 开启限流：30秒内超过6次连接的 IP 直接拒绝
ufw limit ssh/tcp
# 允许标准的 Web 常用端口（可根据需要自行删除或保留）
ufw allow 80/tcp
ufw allow 444/tcp
# 强制启用防火墙（免交互提示）
ufw --force enable
echo "✅ UFW 防火墙已启动，并对 SSH 端口开启了频率限制！"

# 7. 重启 SSH 服务
echo -e "\n🔄 正在重启 SSH 服务..."
if systemctl is-active --quiet ssh; then
    systemctl restart ssh
elif systemctl is-active --quiet sshd; then
    systemctl restart sshd
else
    service ssh restart || service sshd restart
fi

echo "=================================================="
echo "🎉 脚本执行完毕！系统已进入全方位防御状态。"
echo "1. 密码登录已彻底禁用，仅限密钥登录。"
echo "2. Fail2ban 已启动：恶意扫描失败3次封禁1小时。"
echo "3. UFW 限流已启动：连接频率过高直接断开连接。"
echo "⚠️  【防失联警告】：请先不要关闭当前 SSH 窗口！"
echo "👉 请打开一个新终端窗口，尝试用密钥连接，确保能正常登录。"
echo "=================================================="