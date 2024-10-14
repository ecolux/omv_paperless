#!/bin/bash

# Farben für die Visualisierung
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Einführung und Titel
echo -e "${CYAN}###############################################${RESET}"
echo -e "${CYAN} Willkommen zur automatisierten Installation von OMV und Paperless NGX ${RESET}"
echo -e "${CYAN}###############################################${RESET}\n"

# Vorlage für Debian 11
TEMPLATE="debian-11-standard_11.1-1_amd64.tar.gz"  # Überprüfen Sie den genauen Namen
TEMPLATE_PATH="/var/lib/vz/template/cache/$TEMPLATE"

# Überprüfen, ob die Vorlage bereits heruntergeladen wurde
echo -e "${YELLOW}Überprüfe, ob die Debian-Vorlage vorhanden ist...${RESET}"
if [ ! -f "$TEMPLATE_PATH" ]; then
    echo -e "${YELLOW}Debian-Vorlage nicht gefunden. Lade die Vorlage herunter...${RESET}"
    pveam update

    # Überprüfe die Liste der verfügbaren Vorlagen
    echo -e "${YELLOW}Verfügbare Vorlagen:${RESET}"
    pveam available

    # Download der Vorlage
    if pveam download local "$TEMPLATE"; then
        echo -e "${GREEN}Vorlage erfolgreich heruntergeladen!${RESET}"
    else
        echo -e "${YELLOW}Fehler beim Herunterladen der Vorlage. Bitte überprüfe deine Internetverbindung oder den Vorlagennamen.${RESET}"
        exit 1
    fi
else
    echo -e "${GREEN}Debian-Vorlage bereits vorhanden.${RESET}"
fi

# Erstelle den LXC-Container für OpenMediaVault (OMV) - Container ID 100
echo -e "${YELLOW}Erstelle den Container für OpenMediaVault (ID: 100)...${RESET}"

if ! pct config 100 &>/dev/null; then
    pct create 100 local:vztmpl/$TEMPLATE --rootfs local-lvm:8 --memory 2048 --swap 512 --hostname omv-container --net0 name=eth0,bridge=vmbr0,ip=dhcp --cores 2 --ostype debian --arch amd64 --unprivileged 1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OpenMediaVault-Container erfolgreich erstellt!${RESET}"
    else
        echo -e "${YELLOW}Fehler beim Erstellen des OMV-Containers.${RESET}"
        exit 1
    fi
else
    echo -e "${YELLOW}OpenMediaVault-Container mit der ID 100 existiert bereits.${RESET}"
fi

# Erstelle den LXC-Container für Paperless NGX - Container ID 101
echo -e "${YELLOW}Erstelle den Container für Paperless NGX (ID: 101)...${RESET}"

if ! pct config 101 &>/dev/null; then
    pct create 101 local:vztmpl/$TEMPLATE --rootfs local-lvm:8 --memory 2048 --swap 512 --hostname paperless-container --net0 name=eth0,bridge=vmbr0,ip=dhcp --cores 2 --ostype debian --arch amd64 --unprivileged 1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Paperless NGX-Container erfolgreich erstellt!${RESET}"
    else
        echo -e "${YELLOW}Fehler beim Erstellen des Paperless NGX-Containers.${RESET}"
        exit 1
    fi
else
    echo -e "${YELLOW}Paperless NGX-Container mit der ID 101 existiert bereits.${RESET}"
fi

# Starte beide Container
echo -e "${YELLOW}Starte die Container...${RESET}"

pct start 100
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OpenMediaVault-Container erfolgreich gestartet!${RESET}"
else
    echo -e "${YELLOW}Fehler beim Starten des OpenMediaVault-Containers.${RESET}"
    exit 1
fi

pct start 101
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Paperless NGX-Container erfolgreich gestartet!${RESET}"
else
    echo -e "${YELLOW}Fehler beim Starten des Paperless NGX-Containers.${RESET}"
    exit 1
fi

# Hier können zusätzliche Installationsschritte für OMV und Paperless NGX hinzugefügt werden.
# Beispiel: pct exec 100 apt update && pct exec 100 apt install openmediavault -y

# Skriptende
echo -e "${GREEN}Installation abgeschlossen! Die Container laufen nun.${RESET}"
