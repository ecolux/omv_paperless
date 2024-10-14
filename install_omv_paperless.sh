#!/bin/bash

# ANSI-Farbcode-Definitionen für visuelle Effekte
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BACKGROUND_BLUE='\033[44m'
BACKGROUND_CYAN='\033[46m'
BACKGROUND_GREEN='\033[42m'

# Titel und Einführung
echo -e "${BACKGROUND_BLUE}${CYAN}###############################################${RESET}"
echo -e "${BACKGROUND_BLUE}${CYAN} Willkommen zur automatisierten Installation von OMV und Paperless NGX ${RESET}"
echo -e "${BACKGROUND_BLUE}${CYAN}###############################################${RESET}\n"

# Skriptdatei erstellen
SCRIPT_NAME="install_omv_paperless.sh"
cat << 'EOF' > $SCRIPT_NAME
#!/bin/bash

# ANSI-Farbcode-Definitionen für visuelle Effekte
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BACKGROUND_BLUE='\033[44m'
BACKGROUND_CYAN='\033[46m'
BACKGROUND_GREEN='\033[42m'

# Funktion zur automatischen Generierung von Benutzernamen und Passwörtern
generate_random_string() {
    LENGTH=$1
    echo $(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w $LENGTH | head -n 1)
}

# Automatisch generierte Benutzernamen und Passwörter
OMV_SMB_USER=$(generate_random_string 8)
OMV_SMB_PASSWORD=$(generate_random_string 12)
PAPERLESS_USER=$(generate_random_string 8)
PAPERLESS_PASSWORD=$(generate_random_string 12)

# IP-Adresse des OpenMediaVault LXC-Containers erfragen
echo -e "${BACKGROUND_CYAN}${CYAN}--- OpenMediaVault (OMV) Konfiguration ---${RESET}"
read -p "$(echo -e ${YELLOW}"Gib die IP-Adresse des OpenMediaVault LXC-Containers ein (z. B. 192.168.1.100): "${RESET}) " OMV_IP

# Variablen für die Container-Namen und IDs
OMV_CONTAINER_NAME="openmediavault"
OMV_CONTAINER_ID=100
PAPERLESS_CONTAINER_NAME="paperless"
PAPERLESS_CONTAINER_ID=101
SHARE_NAME="scanner_share"
SCAN_FOLDER="/mnt/shared_storage/scans"

# LXC-Container für OpenMediaVault erstellen
echo -e "${GREEN}Erstelle LXC-Container für OpenMediaVault...${RESET}"
pct create $OMV_CONTAINER_ID local:vztmpl/debian-11-standard_11.0-1_amd64.tar.gz --hostname $OMV_CONTAINER_NAME --storage local-lvm --rootfs 8 --net0 name=eth0,bridge=vmbr0,firewall=1 --ostype debian --memory 2048 --swap 512 --cores 2 --unprivileged 1 --features nesting=1
pct start $OMV_CONTAINER_ID

echo -e "${YELLOW}Warte 10 Sekunden, bis der Container gestartet ist...${RESET}"
sleep 10

# OpenMediaVault im LXC-Container installieren
echo -e "${GREEN}Installiere OpenMediaVault im Container $OMV_CONTAINER_ID...${RESET}"
pct exec $OMV_CONTAINER_ID -- bash -c "apt-get update && apt-get install -y wget sudo && \
    wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | bash"

# Plugins und Updates in OMV installieren
echo -e "${GREEN}Aktualisiere OpenMediaVault und installiere zusätzliche Plugins...${RESET}"
pct exec $OMV_CONTAINER_ID -- bash -c "apt-get update && apt-get upgrade -y && \
    omv-salt deploy run system && \
    apt-get install -y openmediavault-omvextrasorg && omv-salt deploy run omvextras && \
    apt-get install -y openmediavault-samba openmediavault-docker-gui"

# SMB-Share und Nutzer in OMV einrichten
echo -e "${GREEN}Konfiguriere SMB-Share in OpenMediaVault...${RESET}"
pct exec $OMV_CONTAINER_ID -- bash -c "mkdir -p $SCAN_FOLDER && \
    chmod 777 $SCAN_FOLDER && \
    echo -e \"[$SHARE_NAME]\n   path = $SCAN_FOLDER\n   guest ok = no\n   valid users = $OMV_SMB_USER\n   read only = no\n   browsable = yes\" >> /etc/samba/smb.conf && \
    useradd -m -s /bin/bash $OMV_SMB_USER && echo -e \"$OMV_SMB_PASSWORD\n$OMV_SMB_PASSWORD\" | smbpasswd -a $OMV_SMB_USER && \
    systemctl restart smbd"

# Docker in OMV aktivieren
echo -e "${GREEN}Aktiviere Docker in OpenMediaVault...${RESET}"
pct exec $OMV_CONTAINER_ID -- bash -c "omv-salt deploy run docker && \
    systemctl enable docker && systemctl start docker"

# LXC-Container für Paperless NGX erstellen
echo -e "${GREEN}Erstelle LXC-Container für Paperless NGX...${RESET}"
pct create $PAPERLESS_CONTAINER_ID local:vztmpl/debian-11-standard_11.0-1_amd64.tar.gz --hostname $PAPERLESS_CONTAINER_NAME --storage local-lvm --rootfs 8 --net0 name=eth0,bridge=vmbr0,firewall=1 --ostype debian --memory 2048 --swap 512 --cores 2 --unprivileged 1 --features nesting=1
pct start $PAPERLESS_CONTAINER_ID

echo -e "${YELLOW}Warte 10 Sekunden, bis der Container gestartet ist...${RESET}"
sleep 10

# Paperless NGX im LXC-Container installieren
echo -e "${GREEN}Installiere Paperless NGX im Container $PAPERLESS_CONTAINER_ID...${RESET}"
pct exec $PAPERLESS_CONTAINER_ID -- bash -c "apt-get update && apt-get install -y docker.io docker-compose"

# Docker-Container für Paperless NGX erstellen und starten
echo -e "${GREEN}Erstelle und starte Paperless NGX Docker-Container...${RESET}"
pct exec $PAPERLESS_CONTAINER_ID -- bash -c "
docker run -d \
    --name paperless-ngx \
    -e PUID=1000 -e PGID=1000 \
    -e TZ=Europe/Berlin \
    -v /mnt/shared_storage/scans:/usr/src/paperless/data/import \
    -v /mnt/shared_storage/paperless:/usr/src/paperless/data \
    -p 8000:8000 \
    paperlessngx/paperless-ngx
"

# Zusammenfassung der generierten Benutzernamen und Passwörter
echo -e "\n${BACKGROUND_GREEN}${CYAN}------------------------------------${RESET}"
echo -e "${BACKGROUND_GREEN}${CYAN}  Installation abgeschlossen! Hier sind die generierten Daten:  ${RESET}"
echo -e "${BACKGROUND_GREEN}${CYAN}------------------------------------${RESET}"
echo -e "${CYAN}OpenMediaVault IP-Adresse:${RESET} \$OMV_IP"
echo -e "${CYAN}SMB-Share Pfad:${RESET} //\$OMV_IP/\$SHARE_NAME"
echo -e "${CYAN}SMB Benutzername:${RESET} \$OMV_SMB_USER"
echo -e "${CYAN}SMB Passwort:${RESET} \$OMV_SMB_PASSWORD"
echo -e "${CYAN}Paperless NGX Benutzername:${RESET} \$PAPERLESS_USER"
echo -e "${CYAN}Paperless NGX Passwort:${RESET} \$PAPERLESS_PASSWORD"
echo -e "${CYAN}Paperless NGX Weboberfläche unter:${RESET} http://\$OMV_IP:8000"

# Ende des Skripts
echo -e "${BACKGROUND_GREEN}${CYAN}------------------------------------${RESET}"
echo -e "${BACKGROUND_GREEN}${CYAN}          Fertig! Viel Spaß!         ${RESET}"
echo -e "${BACKGROUND_GREEN}${CYAN}------------------------------------${RESET}"
EOF

# Mach das Skript ausführbar
chmod +x $SCRIPT_NAME

# Das Skript automatisch ausführen
echo -e "${GREEN}Führe das Skript zur Installation von OMV und Paperless NGX aus...${RESET}"
./$SCRIPT_NAME
