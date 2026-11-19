#!/usr/bin/env bash
# Cypher Tool kurulum betiği
#   Klasörden:      bash kur.sh
#   Tek satır (herhangi bir Linux'ta):
#     curl -fsSL https://raw.githubusercontent.com/Monq12/Cypher-Tool/main/kur.sh | bash
set -euo pipefail

REPO_URL="${CYPHERTOOL_REPO:-https://github.com/Monq12/Cypher-Tool}"
APP_HOME="$HOME/.local/share/cyphertool"
BIN="$HOME/.local/bin"
P='\033[95m'; B='\033[1m'; G='\033[92m'; Y='\033[93m'; R='\033[0m'

echo -e "${P}${B}"
echo "   ╔═══════════════════════════════╗"
echo "   ║        C Y P H E R  T O O L    ║"
echo -e "   ╚═══════════════════════════════╝${R}"

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
pm=""; for x in apt-get dnf pacman zypper apk; do command -v $x >/dev/null 2>&1 && { pm=$x; break; }; done

need=()
command -v python3 >/dev/null 2>&1 || need+=(python3)
command -v git >/dev/null 2>&1 || need+=(git)
if [ ${#need[@]} -gt 0 ]; then
  echo -e "${Y}Eksik temel paketler: ${need[*]} — kuruluyor (parola istenebilir)…${R}"
  case $pm in
    apt-get) $SUDO apt-get update && $SUDO apt-get install -y "${need[@]}" ;;
    dnf)     $SUDO dnf install -y "${need[@]}" ;;
    pacman)  $SUDO pacman -S --needed --noconfirm "${need[@]/python3/python}" ;;
    zypper)  $SUDO zypper --non-interactive install "${need[@]}" ;;
    apk)     $SUDO apk add "${need[@]}" ;;
    *) echo "Paket yöneticisi bulunamadı; python3 ve git'i elle kur."; exit 1 ;;
  esac
fi
# emoji yazı tipi (arayüzdeki simgeler için; yoksa kutucuk görünür)
if ! fc-list 2>/dev/null | grep -qi "emoji"; then
  case $pm in
    apt-get) $SUDO apt-get install -y fonts-noto-color-emoji >/dev/null 2>&1 || true ;;
    dnf)     $SUDO dnf install -y google-noto-emoji-color-fonts >/dev/null 2>&1 || true ;;
    pacman)  $SUDO pacman -S --needed --noconfirm noto-fonts-emoji >/dev/null 2>&1 || true ;;
    zypper)  $SUDO zypper --non-interactive install noto-coloremoji-fonts >/dev/null 2>&1 || true ;;
  esac
fi
# ── İlk kurulum: uygulamanın tüm özellikleri için gerekenler (yalnızca eksikler kurulur; biri kurulamazsa devam edilir) ──
#   python venv/pip · derleyici · curl/wget/unzip/7z · git-lfs · bildirimler · xdg-utils · masaüstü kontrolü (xdotool, wmctrl, scrot, python3-pil)
#   ve uygulama içi tarayıcı için Google Chrome (yoksa Chromium)
inst() { case $pm in
    apt-get) $SUDO apt-get install -y --no-install-recommends "$@" >/dev/null 2>&1 ;;
    dnf)     $SUDO dnf install -y "$@" >/dev/null 2>&1 ;;
    pacman)  $SUDO pacman -S --needed --noconfirm "$@" >/dev/null 2>&1 ;;
    zypper)  $SUDO zypper --non-interactive install "$@" >/dev/null 2>&1 ;;
    apk)     $SUDO apk add "$@" >/dev/null 2>&1 ;;
  esac; }
case $pm in
  apt-get) PK="python3-venv python3-pip build-essential curl wget unzip p7zip-full git-lfs libnotify-bin xdg-utils xdotool wmctrl scrot python3-pil ca-certificates" ;;
  dnf)     PK="python3-pip gcc gcc-c++ make curl wget unzip p7zip git-lfs libnotify xdg-utils xdotool wmctrl scrot python3-pillow" ;;
  pacman)  PK="python-pip base-devel curl wget unzip p7zip git-lfs libnotify xdg-utils xdotool wmctrl scrot python-pillow" ;;
  zypper)  PK="python3-pip gcc gcc-c++ make curl wget unzip p7zip git-lfs libnotify-tools xdg-utils xdotool wmctrl scrot python3-Pillow" ;;
  apk)     PK="py3-pip build-base curl wget unzip p7zip git-lfs libnotify xdg-utils xdotool wmctrl scrot py3-pillow" ;;
  *)       PK="" ;;
esac
missing=()
for p_ in $PK; do
  if [ "$pm" = "apt-get" ]; then dpkg -s "$p_" >/dev/null 2>&1 || missing+=("$p_")
  elif [ "$pm" = "pacman" ]; then pacman -Qi "$p_" >/dev/null 2>&1 || missing+=("$p_")
  elif command -v rpm >/dev/null 2>&1 && [ "$pm" != "apk" ]; then rpm -q "$p_" >/dev/null 2>&1 || missing+=("$p_")
  else missing+=("$p_"); fi
done
if [ ${#missing[@]} -gt 0 ]; then
  echo -e "${Y}🧩 İlk kurulum: ${#missing[@]} gerekli paket kuruluyor (${missing[*]}) — birkaç dakika sürebilir…${R}"
  [ "$pm" = "apt-get" ] && $SUDO apt-get update >/dev/null 2>&1 || true
  inst "${missing[@]}" || for p_ in "${missing[@]}"; do inst "$p_" || echo "   ⚠ $p_ kurulamadı (sonra Sistem sekmesinden denenebilir)"; done
fi
# uygulama içi tarayıcı (yapay zekânın internette gezinmesi için Chrome/Chromium gerekir)
if ! command -v google-chrome >/dev/null 2>&1 && ! command -v google-chrome-stable >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1 \
   && ! command -v chromium-browser >/dev/null 2>&1 && ! command -v brave-browser >/dev/null 2>&1 && ! command -v microsoft-edge >/dev/null 2>&1; then
  echo -e "${Y}🌐 Tarayıcı kuruluyor (Google Chrome)…${R}"
  ARCH="$(uname -m)"
  if [ "$pm" = "apt-get" ] && [ "$ARCH" = "x86_64" ]; then
    T_="$(mktemp -d)"; curl -fsSL -o "$T_/chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
      && $SUDO apt-get install -y "$T_/chrome.deb" >/dev/null 2>&1 || inst chromium || inst chromium-browser || echo "   ⚠ Chrome kurulamadı — Sistem sekmesinden ya da elle kur."
    rm -rf "$T_"
  elif [ "$pm" = "dnf" ] && [ "$ARCH" = "x86_64" ]; then
    $SUDO dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm >/dev/null 2>&1 || inst chromium || echo "   ⚠ Chrome kurulamadı."
  else
    inst chromium || inst chromium-browser || echo "   ⚠ Chromium kurulamadı."
  fi
fi
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,9) else 1)' || { echo "Python 3.9+ gerekli."; exit 1; }

# Sadece betik bir DOSYA olarak çalıştırıldıysa yanındaki dosyaları kullan; "curl … | bash" ile çalıştırılınca
# o an bulunulan klasördeki (olası eski) cyphertool.py'yi değil, her zaman GitHub'daki güncel sürümü indir.
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
fi
if [ -z "$SRC" ] || [ ! -f "$SRC/cyphertool.py" ]; then
  echo "⬇ Cypher Tool indiriliyor: $REPO_URL"
  SRC="$(mktemp -d)"; git clone --depth 1 "$REPO_URL" "$SRC/ct" >/dev/null 2>&1 || { echo "İndirilemedi: $REPO_URL"; exit 1; }; SRC="$SRC/ct"
  # repoda sadece zip varsa onu aç (sürüm numaralı zip varsa en yenisi: cyphertool-1.1.0.zip > cyphertool.zip)
  if [ ! -f "$SRC/cyphertool.py" ]; then
    Z="$(ls "$SRC"/cyphertool-*.zip 2>/dev/null | sort -V | tail -n1)"
    [ -z "$Z" ] && [ -f "$SRC/cyphertool.zip" ] && Z="$SRC/cyphertool.zip"
    if [ -n "$Z" ]; then
      echo "📦 Arşivden kuruluyor: $(basename "$Z")"
      python3 -m zipfile -e "$Z" "$SRC/_z" && SRC="$(dirname "$(find "$SRC/_z" -name cyphertool.py | head -n1)")"
    fi
  fi
fi

mkdir -p "$APP_HOME" "$BIN" "$HOME/.local/share/applications"
rm -rf "$APP_HOME/web"   # eski arayüz dosyaları kalmasın
cp -r "$SRC/cyphertool.py" "$SRC/catalog.json" "$SRC/web" "$APP_HOME/"
[ -f "$SRC/hata_bankasi.json" ] && cp "$SRC/hata_bankasi.json" "$APP_HOME/"
[ -f "$SRC/README.md" ] && cp "$SRC/README.md" "$APP_HOME/"
chmod +x "$APP_HOME/cyphertool.py"
ln -sf "$APP_HOME/cyphertool.py" "$BIN/cyphertool"
ln -sf "$APP_HOME/cyphertool.py" "$BIN/ct"

# uygulama penceresi için tarayıcı kontrolü (yalnızca bilgi)
if ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1 && ! command -v google-chrome >/dev/null 2>&1 \
   && ! command -v brave-browser >/dev/null 2>&1 && ! command -v firefox >/dev/null 2>&1; then
  echo -e "${Y}Not: Arayüz bir tarayıcı penceresinde açılır. Chromium/Chrome/Brave önerilir (uygulama penceresi gibi görünür).${R}"
fi

# menü + masaüstü kısayolu
DESK="$(xdg-user-dir DESKTOP 2>/dev/null || true)"; [ -z "$DESK" ] || [ "$DESK" = "$HOME" ] && DESK=""
for d in "$HOME/Masaüstü" "$HOME/Desktop"; do [ -z "$DESK" ] && [ -d "$d" ] && DESK="$d"; done
ENTRY="[Desktop Entry]
Type=Application
Name=Cypher Tool
Comment=GitHub araçlarını kur, yönet ve çalıştır • Yapay zekâ ajanları
Exec=$APP_HOME/cyphertool.py
Icon=$APP_HOME/web/logo.svg
Terminal=false
Categories=Development;Utility;
StartupWMClass=CypherTool"
echo "$ENTRY" > "$HOME/.local/share/applications/cyphertool.desktop"
if [ -n "$DESK" ]; then
  echo "$ENTRY" > "$DESK/cyphertool.desktop"; chmod +x "$DESK/cyphertool.desktop"
  command -v gio >/dev/null 2>&1 && gio set "$DESK/cyphertool.desktop" metadata::trusted true 2>/dev/null || true
fi

# günlük güncelleme kontrolü (uygulama kapalıyken de)
if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
  U="$HOME/.config/systemd/user"; mkdir -p "$U"
  cat > "$U/cyphertool-kontrol.service" <<EOF
[Unit]
Description=Cypher Tool günlük güncelleme kontrolü
[Service]
Type=oneshot
ExecStart=/usr/bin/env python3 $APP_HOME/cyphertool.py kontrol
EOF
  cat > "$U/cyphertool-kontrol.timer" <<EOF
[Unit]
Description=Cypher Tool günlük güncelleme kontrolü
[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true
[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload && systemctl --user enable --now cyphertool-kontrol.timer >/dev/null 2>&1 || true
  echo "✔ Günlük güncelleme kontrolü etkin (systemd --user)"
fi

case ":$PATH:" in *":$BIN:"*) ;; *)
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] && ! grep -q 'cyphertool-path' "$rc" && echo 'export PATH="$HOME/.local/bin:$PATH" # cyphertool-path' >> "$rc"
  done
  echo -e "${Y}Yeni bir terminal aç (PATH güncellendi).${R}";;
esac

echo -e "${G}${B}✔ Cypher Tool kuruldu! ($(grep -m1 '^VERSION' "$APP_HOME/cyphertool.py" | cut -d'"' -f2) sürümü)${R}"
echo "  • Aç:              Menüden/masaüstünden 'Cypher Tool'  ya da  cyphertool"
echo "  • Terminalden kur: ct https://github.com/sahip/proje"
echo "  • Toplu kur:       ct link1 link2 link3"
if [ -t 0 ]; then
  read -rp "Şimdi açılsın mı? [E/h] " a || a=h
  if [[ "${a:-e}" =~ ^[Ee]?$ ]]; then nohup "$APP_HOME/cyphertool.py" >/dev/null 2>&1 & fi
elif [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  echo "▶ Cypher Tool açılıyor…"; nohup "$APP_HOME/cyphertool.py" >/dev/null 2>&1 &
fi
