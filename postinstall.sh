#!/bin/bash

# === Benutzer-Eingaben ===
echo "🛠 Post-Install Setup für Ubuntu 24.04"
read -p "👉 Neuer Benutzername: " NEW_USER
read -p "📜 SSH Public Key (z. B. beginnt mit ssh-ed25519): " SSH_KEY
read -p "🔐 Root-Login via SSH deaktivieren? (j/n): " DISABLE_ROOT

# === System vorbereiten ===
echo "🌍 Zeitzone auf Europa/Berlin setzen..."
timedatectl set-timezone Europe/Berlin

# === Basis-Pakete ===
echo "📦 Pakete installieren..."
apt update && apt install -y \
  docker.io docker-compose \
  nginx certbot python3-certbot-nginx \
  fail2ban ufw unattended-upgrades \
  net-tools curl git

# === Docker-Gruppe sicherstellen ===
if ! getent group docker > /dev/null; then
    echo "➕ Docker-Gruppe anlegen..."
    groupadd docker
fi

# === Firewall konfigurieren ===
echo "🔥 Firewall konfigurieren (UFW)..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# === Sicherheitsupdates aktivieren ===
echo "♻️ Sicherheitsupdates aktivieren..."
dpkg-reconfigure --priority=low unattended-upgrades

# === Neuen Benutzer anlegen ===
echo "👤 Benutzer '$NEW_USER' wird erstellt..."
adduser $NEW_USER
usermod -aG sudo,docker $NEW_USER

# === SSH-Zugang konfigurieren ===
echo "🔐 SSH-Key setzen für $NEW_USER..."
mkdir -p /home/$NEW_USER/.ssh
echo "$SSH_KEY" > /home/$NEW_USER/.ssh/authorized_keys
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh
chmod 600 /home/$NEW_USER/.ssh/authorized_keys

# === SSH-Konfiguration absichern ===
echo "🔒 SSH-Konfiguration absichern..."
grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config \
  && sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
  || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

grep -q "^AuthorizedKeysFile" /etc/ssh/sshd_config \
  || echo "AuthorizedKeysFile .ssh/authorized_keys" >> /etc/ssh/sshd_config

# === SSH-Konfiguration testen & neuladen ===
echo "🧪 SSH-Konfig testen..."
if sshd -t; then
    echo "🔁 SSH wird neu geladen..."
    systemctl reload ssh
else
    echo "❌ SSH-Konfiguration fehlerhaft! Bitte manuell prüfen."
    exit 1
fi

# === Root-Login deaktivieren ===
if [[ "$DISABLE_ROOT" == "j" ]]; then
    echo "🚫 Root-Login via SSH deaktivieren..."
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sshd -t && systemctl reload ssh
else
    echo "⚠️ Root-Login bleibt erlaubt."
fi

# === Done ===
echo "✅ Setup abgeschlossen! Logge dich ein mit:"
echo "👉 ssh -i /pfad/zum/key $NEW_USER@DEINE-IP"