#!/bin/bash
# Linux 一键安全加固脚本 V4.1 (防爆破防扫描)

if [ "$EUID" -ne 0 ]; then
  echo "❌ 请以 root 用户运行此脚本！"
  exit 1
fi

echo "=================================================="
echo " Linux 一键安全加固脚本 V4.1"
echo "=================================================="

# 1. 交互获取公钥
read -p "👉 请粘贴你的 SSH 公钥 (例如 ssh-ed25519 ...): " SSH_KEY
if [ -z "$SSH_KEY" ]; then
    echo "❌ 错误：公钥不能为空！"
    exit 1
fi

# 2. 基础工具安装
echo -e "\n🔄 正在安装基础工具及安全软件..."
apt update && apt install -y unzip curl vim wget fail2ban ufw unattended-upgrades

# 3. 配置 SSH 密钥（防止重复）
echo -e "\n🔑 正在配置 SSH 公钥..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# 检查是否已存在该公钥，避免重复
if ! grep -qF "$SSH_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
    echo "$SSH_KEY" >> /root/.ssh/authorized_keys
    echo "✅ 公钥已添加"
else
    echo "✅ 公钥已存在，无需重复添加"
fi
chmod 600 /root/.ssh/authorized_keys

# 4. SSH 安全加固（更全面）
echo -e "\n🛡️ 正在进行 SSH 安全加固..."
SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak.$(date +%F_%H%M)"  # 备份

cat << 'EOF' > /etc/ssh/sshd_config.d/99-security.conf
# === 安全加固配置 ===
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin prohibit-password
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# 5. Fail2ban 配置
echo -e "\n🤖 正在配置 Fail2ban..."
cat << 'EOF' > /etc/fail2ban/jail.local
[DEFAULT]
findtime = 10m
bantime = 1h
maxretry = 3
banaction = iptables-multiport
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
EOF

systemctl daemon-reload
systemctl enable --now fail2ban

# 6. UFW 防火墙（可扩展）
echo -e "\n🧱 正在配置 UFW 防火墙..."
ufw --force reset --yes >/dev/null 2>&1 || true  # 可选：重置（谨慎使用）

ufw allow ssh
ufw limit ssh/tcp                # 防暴力破解
ufw allow 80/tcp
ufw allow 443/tcp                # HTTPS 推荐

ufw --force enable

echo "✅ UFW 已启动（当前开放端口可通过 ufw status 查看）"

# 7. 启用自动安全更新
echo -e "\n🔄 启用自动安全更新..."
cat << 'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# 8. 重启 SSH
echo -e "\n🔄 正在重启 SSH 服务..."
systemctl restart ssh || systemctl restart sshd

echo "=================================================="
echo "🎉 加固完成！"
echo "1. 仅密钥登录 + Fail2ban + UFW 限流"
2. 已启用自动安全更新"
echo "3. SSH 配置已备份"
echo "⚠️ 请在新窗口测试密钥登录后再关闭当前窗口！"
echo "=================================================="

# 显示当前 UFW 状态
echo "当前防火墙状态："
ufw status numbered
