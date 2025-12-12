#!/bin/bash

# =================KONFIGURATION=================
CONFIG_FILE="$HOME/.munki_audit.conf"
PREFIX="app_"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Dateinamen Ausgaben
OUT_APPS_FULL="Export_Apps_Complete.csv"
OUT_APPS_UNIQUE="Export_Apps_Unique_Clean.csv"
OUT_OTHERS_FULL="Export_Andere_Complete.csv"
OUT_OTHERS_UNIQUE="Export_Andere_Unique.csv"
# ===============================================

# Lade Konfiguration
load_config() {
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    REPO_PATH=""
fi
}

# Speichere Konfiguration
save_config() {
echo "REPO_PATH=\"$REPO_PATH\"" > "$CONFIG_FILE"
}

pause() {
echo ""
read -p "Drücke [Enter] um fortzufahren..."
}

# Progress Bar Funktion
draw_progress_bar() {
local _current=$1
local _total=$2
local _width=$(tput cols 2>/dev/null || echo 80)
local _bar_size=$(( _width - 25 ))
local _percent=$(( 100 * _current / _total ))
local _filled=$(( _percent * _bar_size / 100 ))
local _empty=$(( _bar_size - _filled ))

printf "\r["
printf "%0.s#" $(seq 1 $_filled)
if [ $_empty -gt 0 ]; then
    printf "%0.s." $(seq 1 $_empty)
fi
printf "] %d%% (%d/%d)" "$_percent" "$_current" "$_total"
}

# === HAUPTFUNKTION AUDIT ===
run_audit() {
clear
echo -e "${BLUE}=== Munki Repository Audit ===${NC}"

if [ -z "$REPO_PATH" ] || [ ! -d "$REPO_PATH/manifests" ]; then
    echo -e "${RED}FEHLER: Kein gültiges Munki-Repository konfiguriert.${NC}"
    echo "Bitte gehe in die Einstellungen und setze den Pfad."
    pause
    return
fi

echo "Initialisiere Dateiliste aus: $REPO_PATH/manifests"

# Array füllen (kompatibel mit älteren Bash Versionen auf macOS)
file_list=()
while IFS=  read -r -d $'\0'; do
    file_list+=("$REPLY")
done < <(find "$REPO_PATH/manifests" -type f -not -name '.*' -print0)

total_files=${#file_list[@]}

if [ "$total_files" -eq 0 ]; then
    echo -e "${RED}Keine Manifest-Dateien gefunden!${NC}"
    pause
    return
fi

echo "Gefundene Manifeste: $total_files"
echo "Starte Analyse..."
echo ""

TMP_APPS=$(mktemp)
TMP_OTHERS=$(mktemp)
KEYS=("managed_installs" "optional_installs" "managed_uninstalls" "featured_items")

current_count=0

for manifest_file in "${file_list[@]}"; do
    ((current_count++))
    draw_progress_bar $current_count $total_files
    
    rel_path="${manifest_file#$REPO_PATH/manifests/}"

    for key in "${KEYS[@]}"; do
        # Technische Logik: plutil extrahiert JSON
        json_output=$(plutil -extract "$key" json -o - "$manifest_file" 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            items=$(echo "$json_output" | tr -d '[]"' | tr ',' '\n' | sed '/^$/d' | sed 's/^[ \t]*//')

            while read -r item; do
                if [[ -n "$item" ]]; then
                    if [[ "$item" == "$PREFIX"* ]]; then
                        echo "$rel_path;$key;$item" >> "$TMP_APPS"
                    else
                        echo "$rel_path;$key;$item" >> "$TMP_OTHERS"
                    fi
                fi
            done <<< "$items"
        fi
    done
done

echo -e "\n\n${GREEN}Parsing abgeschlossen! Erstelle CSV-Dateien...${NC}"

# EXPORTE
echo "Manifest;Sektion;Objekt" > "$OUT_APPS_FULL"
[ -s "$TMP_APPS" ] && sort -t';' -k3,3 -k1,1 -f "$TMP_APPS" >> "$OUT_APPS_FULL"

echo "Programm Name" > "$OUT_APPS_UNIQUE"
[ -s "$TMP_APPS" ] && cut -d';' -f3 "$TMP_APPS" | sed "s/^$PREFIX//" | sort -f | uniq >> "$OUT_APPS_UNIQUE"

echo "Manifest;Sektion;Objekt" > "$OUT_OTHERS_FULL"
[ -s "$TMP_OTHERS" ] && sort -t';' -k3,3 -k1,1 -f "$TMP_OTHERS" >> "$OUT_OTHERS_FULL"

echo "Objekt Name" > "$OUT_OTHERS_UNIQUE"
[ -s "$TMP_OTHERS" ] && cut -d';' -f3 "$TMP_OTHERS" | sort -f | uniq >> "$OUT_OTHERS_UNIQUE"

rm "$TMP_APPS" "$TMP_OTHERS"

echo "------------------------------------------------"
echo -e "${GREEN}Erfolgreich! Folgende Dateien wurden erstellt:${NC}"
echo " - $OUT_APPS_FULL"
echo " - $OUT_APPS_UNIQUE"
echo " - $OUT_OTHERS_FULL"
echo " - $OUT_OTHERS_UNIQUE"
echo "------------------------------------------------"
pause
}

# === EINSTELLUNGEN ===
configure_repo() {
while true; do
    clear
    echo -e "${BLUE}=== Einstellungen ===${NC}"
    
    if [ -z "$REPO_PATH" ]; then
        echo -e "Aktueller Pfad: ${RED}Nicht gesetzt${NC}"
    else
        echo -e "Aktueller Pfad: ${GREEN}$REPO_PATH${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}HINWEIS ZUM PFAD:${NC}"
    echo "Bitte gib den Pfad zum Hauptordner (Root) des Munki-Repos an."
    echo "Das ist der Ordner, der die Unterordner 'manifests', 'pkgsinfo' usw. enthält."
    echo ""
    echo -e "${CYAN}Richtig:   /Volumes/DEBHG-MUR01${NC}"
    echo -e "${RED}Falsch:    /Volumes/DEBHG-MUR01/manifests${NC}"
    echo ""
    echo "Neuen Pfad eingeben (oder Enter für Abbruch):"
    echo -n "> "
    read input_path

    if [ -z "$input_path" ]; then
        break
    fi

    input_path="${input_path%/}"

    if [ -d "$input_path/manifests" ]; then
        REPO_PATH="$input_path"
        save_config
        echo -e "${GREEN}Pfad erfolgreich gespeichert!${NC}"
        sleep 1.5
        break
    else
        echo ""
        echo -e "${RED}FEHLER:${NC} Unterordner '/manifests' wurde in diesem Pfad nicht gefunden."
        echo "Hast du vielleicht aus Versehen schon den 'manifests' Ordner ausgewählt?"
        echo "Bitte wähle eine Ebene darüber aus."
        echo ""
        read -p "Drücke Enter um es nochmal zu versuchen..."
    fi
done
}

# === HILFE ===
show_help() {
clear
echo -e "${BLUE}=== Hilfe & Technische Dokumentation ===${NC}"
echo ""
echo -e "${YELLOW}Allgemein:${NC}"
echo "Dieses Script durchsucht das Munki-Repository nach Software-Zuweisungen."
echo "Es exportiert diese in CSV-Dateien, die mit Excel geöffnet werden können."
echo ""
echo -e "${YELLOW}Technische Details (für Support/IT):${NC}"
echo "------------------------------------------------"
echo -e "${CYAN}1. Sicherheit & Zugriff:${NC}"
echo "   - Das Script benötigt nur **Lesezugriff** (Read-Only) auf das Repo."
echo "   - Es werden **keine Änderungen** an Manifest-Dateien vorgenommen."
echo "   - Es werden keine Daten ins Internet gesendet (lokale Verarbeitung)."
echo ""
echo -e "${CYAN}2. Verwendete Befehle (macOS Native):${NC}"
echo -e "   - ${GREEN}find${NC}: Rekursive Suche nach Manifest-Dateien."
echo -e "   - ${GREEN}plutil${NC}: Apple-Tool zum Parsen der XML-Manifeste."
echo "     (Befehl: plutil -extract [key] json -o - [file])"
echo -e "   - ${GREEN}tr / sed / cut${NC}: Textverarbeitung zur Bereinigung der JSON-Daten."
echo -e "   - ${GREEN}sort / uniq${NC}: Alphabetische Sortierung und Deduplizierung."
echo ""
echo -e "${CYAN}3. Funktionsweise:${NC}"
echo "   - Jede Manifest-Datei wird auf die Keys 'managed_installs',"
echo "     'optional_installs', 'managed_uninstalls' geprüft."
echo "   - Die extrahierten Daten werden temporär im RAM/Tmp gespeichert."
echo "   - Unterschied 'Complete' vs 'Unique': Complete listet jede Zuweisung,"
echo "     Unique erstellt eine bereinigte Inventarliste."
echo "------------------------------------------------"
echo ""
pause
}

# === MAIN LOOP ===
load_config

while true; do
clear
echo -e "${BLUE}########################################${NC}"
echo -e "${BLUE}#       MUNKI MANIFEST EXPORTER        #${NC}"
echo -e "${BLUE}########################################${NC}"
echo ""

if [ -n "$REPO_PATH" ]; then
    echo -e "Repo Pfad: ${GREEN}$REPO_PATH${NC}"
else
    echo -e "Repo Pfad: ${RED}NICHT KONFIGURIERT${NC}"
fi

echo ""
echo "1) Audit Starten (CSV Export)"
echo "2) Einstellungen (Pfad ändern)"
echo "3) Hilfe / Tech Info"
echo "4) Beenden"
echo ""
echo -n "Wähle eine Option [1-4]: "
read choice

case $choice in
    1)
        run_audit
        ;;
    2)
        configure_repo
        ;;
    3)
        show_help
        ;;
    4)
        echo "Tschüss!"
        exit 0
        ;;
    *)
        echo -e "${RED}Ungültige Eingabe.${NC}"
        sleep 1
        ;;
esac
done