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

# ── Kurulum günlüğü + canlı ilerleme: her adımda ne yapıldığı, kaç saniyedir sürdüğü ve takıldığı yer ekrana yazılır ──
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/cyphertool-kurulum.log"; mkdir -p "$(dirname "$LOG")"; : > "$LOG"
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 APT_LISTCHANGES_FRONTEND=none
SENV="env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 APT_LISTCHANGES_FRONTEND=none"
APTO="-y -o DPkg::Lock::Timeout=900 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
lockinfo() {   # paket yöneticisini kim tutuyor? apt bunu söyler: "held by process 1234 (unattended-upgr)"
  local h pid name
  h="$(grep -iE 'lock|kilit' "$LOG" 2>/dev/null | grep -oE '[0-9]+ \([A-Za-z0-9._ -]+\)' | tail -n 1)" || true   # dilden bağımsız: "… 1234 (unattended-upgr) …"
  if [ -n "$h" ]; then
    pid="$(echo "$h" | grep -o '[0-9]\+' | head -n 1)"; name="$(echo "$h" | sed 's/.*(\(.*\))/\1/')"
    echo -e "     ${Y}Paket yöneticisini şu işlem kullanıyor: $name (PID $pid, $(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ' || echo '?') süredir)${R}"
    case "$name" in unattended*|apt.systemd*|packagekit*) echo "     Bu Ubuntu'nun otomatik güncellemesi; genelde birkaç dakikada biter, kendiliğinden devam edeceğim.";;
      *) echo "     Başka bir kurulum açık olabilir (Yazılım Merkezi, başka bir terminal). Onu kapatınca kendiliğinden devam ederim.";; esac
  else
    ps -eo pid,etime,comm 2>/dev/null | awk '$3 ~ /^(apt|apt-get|dpkg|unattended-upgr|packagekitd|aptd)$/' | grep -v "^ *$$ " | head -3 \
      | sed 's/^/       /' | { read -r first && { echo "     Çalışan paket işlemleri:"; echo "$first"; cat; }; } || true
  fi
}
# 🦖 bekleme animasyonu: dinozor kendi kendine koşar, kaktüslerin üstünden zıplar (klavyeyle oynanmaz, sadece animasyon)
DINO_W=16   # pist genişliği (her hücre 2 karakter)
dino_init() { DCAC=(); local k; for ((k = 0; k < DINO_W; k++)); do DCAC[k]=0; done; DCAC[$((DINO_W - 3))]=1; DCAC[$((DINO_W - 1))]=1; DGAP=4; DT=0; }
dino_frame() {   # $1 = alttaki durum satırı → 3 satır çizer (gökyüzü / koşu / zemin + durum)
  local k jump=0 sky="" run="" grd=""
  DT=$((DT + 1))
  if [ $((DT % 2)) -eq 0 ]; then   # pist her 2 karede bir kayar
    for ((k = 0; k < DINO_W - 1; k++)); do DCAC[k]=${DCAC[k + 1]}; done
    DGAP=$((DGAP - 1)); if [ $DGAP -le 0 ] && [ $((RANDOM % 3)) -eq 0 ]; then DCAC[$((DINO_W - 1))]=1; DGAP=$((4 + RANDOM % 5)); else DCAC[$((DINO_W - 1))]=0; fi
  fi
  { [ "${DCAC[2]}" = 1 ] || [ "${DCAC[3]}" = 1 ] || [ "${DCAC[1]}" = 1 ]; } && jump=1
  for ((k = 0; k < DINO_W; k++)); do
    if [ $k -eq 2 ] && [ $jump -eq 1 ]; then sky+="🦖"; else sky+="  "; fi
    if [ $k -eq 2 ] && [ $jump -eq 0 ]; then run+="🦖"; elif [ "${DCAC[k]}" = 1 ]; then run+="🌵"; else run+="  "; fi
    if [ $(((k + DT / 2) % 5)) -eq 0 ]; then grd+="._"; else grd+="__"; fi
  done
  printf "\033[2A\r\033[K  %s\n\r\033[K  %s\n\r\033[K  %s  %s" "$sky" "$run" "$grd" "$1"
}
dino_clear() { printf "\r\033[K\033[1A\r\033[K\033[1A\r\033[K"; }
run_step() {   # run_step "etiket" komut… → canlı: dinozor + süre + son çıktı; 90 sn ilerleme yoksa takıldığı yeri yazar
  local label="$1"; shift
  local t0=$SECONDS last="" mark=$SECONDS warned=0 i=0 sp='|/-\' ln el note anim=0
  [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && anim=1
  echo "── $(date '+%H:%M:%S') $label: $*" >>"$LOG"
  ( "$@" ) >>"$LOG" 2>&1 </dev/null &
  local pid=$!
  [ $anim -eq 1 ] && { dino_init; printf "\n\n"; }
  while kill -0 "$pid" 2>/dev/null; do
    ln="$(tail -c 600 "$LOG" 2>/dev/null | tr '\r' '\n' | grep -v '^[[:space:]]*$' | tail -n 1 | cut -c1-80)" || true
    [ "$ln" != "$last" ] && { last="$ln"; mark=$SECONDS; }
    el=$((SECONDS - t0)); note=""
    case "$ln" in *"Could not get lock"*|*"Waiting for cache lock"*|*"lock-frontend"*|*"Kilit"*|*"kilid"*) note=" ⏳ kilit bekleniyor (başka bir güncelleme sürüyor)";; esac
    if [ $anim -eq 1 ]; then dino_frame "$label  ${el}s  ${ln:0:50}$note"
    else [ $((i % 30)) -eq 0 ] && echo "  … $label  ${el}s  ${ln:0:60}$note"; fi
    i=$((i + 1))
    if [ $((SECONDS - mark)) -ge 90 ] && [ $warned -eq 0 ]; then
      warned=1; [ $anim -eq 1 ] && dino_clear
      printf "${Y}  ⚠ 90 sn'dir ilerleme yok. Takıldığı yer: %s${R}\n" "${ln:-"(henüz çıktı yok)"}"; lockinfo
      echo -e "     Ayrıntılar: ${B}$LOG${R}  (beklemeye devam ediyorum; vazgeçmek için Ctrl+C)"
      [ $anim -eq 1 ] && printf "\n\n"
    fi
    if [ $el -ge 900 ]; then kill "$pid" 2>/dev/null || true; [ $anim -eq 1 ] && dino_clear; printf "${Y}  ⏱ 15 dakika geçti, bu adım atlandı: %s${R}\n" "$label"; return 1; fi
    sleep 0.15
  done
  local rc=0; wait "$pid" || rc=$?
  [ $anim -eq 1 ] && dino_clear || printf "\r\033[K"
  return $rc
}
inst() { case $pm in
    apt-get) $SUDO $SENV apt-get install $APTO --no-install-recommends "$@" ;;
    dnf)     $SUDO dnf install -y "$@" ;;
    pacman)  $SUDO pacman -S --needed --noconfirm "$@" ;;
    zypper)  $SUDO zypper --non-interactive install "$@" ;;
    apk)     $SUDO apk add "$@" ;;
  esac; }
NEED_SUDO_ASKED=0
sudo_once() {   # şifreyi baştan bir kez sor; kurulum boyunca hatırlansın (arka plandaki adımlar şifre bekleyip takılmasın)
  [ -z "$SUDO" ] && return 0; [ $NEED_SUDO_ASKED -eq 1 ] && return 0; NEED_SUDO_ASKED=1
  if ! sudo -n true 2>/dev/null; then
    echo -e "${Y}🔐 Paket kurmak için yönetici (sudo) şifren gerekiyor:${R}"
    sudo -v </dev/tty || { echo -e "${Y}Şifre alınamadı; sistem paketleri atlanıyor (uygulama yine kurulur).${R}"; return 1; }
  fi
  ( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
}
UPDATED=0
pm_update() { [ $UPDATED -eq 1 ] && return 0; UPDATED=1; [ "$pm" = "apt-get" ] && { run_step "Paket listesi güncelleniyor" $SUDO $SENV apt-get update -o DPkg::Lock::Timeout=900 || echo -e "  ${Y}⚠ Paket listesi güncellenemedi (internet?) — yine de devam${R}"; }; return 0; }
install_list() {   # install_list "başlık" paket… → her paket ayrı: [2/5 %40] xdotool kuruluyor…
  local title="$1"; shift; local n=$# k=0 ok=0 bad=()
  [ $n -eq 0 ] && return 0
  sudo_once || return 0; pm_update
  echo -e "${Y}🧩 $title: $n paket${R}"
  for p_ in "$@"; do
    k=$((k + 1))
    if run_step "[$k/$n %$((k * 100 / n))] $p_ kuruluyor" inst "$p_"; then ok=$((ok + 1)); echo -e "  ${G}✔${R} [$k/$n] $p_"
    else bad+=("$p_"); echo -e "  ${Y}✖${R} [$k/$n] $p_ kurulamadı — son satır: $(tail -n 2 "$LOG" | tr '\r' ' ' | tail -n 1 | cut -c1-100)"; fi
  done
  [ ${#bad[@]} -gt 0 ] && echo -e "  ${Y}Kurulamayanlar: ${bad[*]} — uygulama yine çalışır; sonra Sistem sekmesinden denenebilir. Günlük: $LOG${R}"
  return 0
}

need=()
command -v python3 >/dev/null 2>&1 || need+=(python3)
command -v git >/dev/null 2>&1 || need+=(git)
if [ ${#need[@]} -gt 0 ]; then
  [ -z "$pm" ] && { echo "Paket yöneticisi bulunamadı; python3 ve git'i elle kur."; exit 1; }
  [ "$pm" = "pacman" ] && need=("${need[@]/python3/python}")
  install_list "Temel paketler" "${need[@]}"
  command -v python3 >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || { echo "python3 ve git kurulamadı — günlük: $LOG"; exit 1; }
fi
# ── İlk kurulum: uygulamanın tüm özellikleri için gerekenler (yalnızca eksikler kurulur; biri kurulamazsa devam edilir) ──
#   python venv/pip · derleyici · curl/wget/unzip/7z · git-lfs · bildirimler · xdg-utils · masaüstü kontrolü (xdotool, wmctrl, scrot, python3-pil) · emoji yazı tipi · dosya inceleme (pdftotext, file, readelf, 7zip — exe/dll/pdf/rar)
case $pm in
  apt-get) PK="python3-venv python3-pip build-essential curl wget unzip p7zip-full git-lfs libnotify-bin xdg-utils xdotool wmctrl scrot python3-pil ca-certificates fonts-noto-color-emoji poppler-utils file binutils 7zip bubblewrap" ;;
  dnf)     PK="python3-pip gcc gcc-c++ make curl wget unzip p7zip git-lfs libnotify xdg-utils xdotool wmctrl scrot python3-pillow google-noto-emoji-color-fonts poppler-utils file binutils bubblewrap" ;;
  pacman)  PK="python-pip base-devel curl wget unzip p7zip git-lfs libnotify xdg-utils xdotool wmctrl scrot python-pillow noto-fonts-emoji poppler file binutils bubblewrap" ;;
  zypper)  PK="python3-pip gcc gcc-c++ make curl wget unzip p7zip git-lfs libnotify-tools xdg-utils xdotool wmctrl scrot python3-Pillow noto-coloremoji-fonts poppler-tools file binutils bubblewrap" ;;
  apk)     PK="py3-pip build-base curl wget unzip p7zip git-lfs libnotify xdg-utils xdotool wmctrl scrot py3-pillow poppler-utils file binutils bubblewrap" ;;
  *)       PK="" ;;
esac
missing=()
for p_ in $PK; do
  if [ "$pm" = "apt-get" ]; then dpkg -s "$p_" >/dev/null 2>&1 || missing+=("$p_")
  elif [ "$pm" = "pacman" ]; then pacman -Qi "$p_" >/dev/null 2>&1 || missing+=("$p_")
  elif command -v rpm >/dev/null 2>&1 && [ "$pm" != "apk" ]; then rpm -q "$p_" >/dev/null 2>&1 || missing+=("$p_")
  else missing+=("$p_"); fi
done
[ ${#missing[@]} -gt 0 ] && install_list "İlk kurulum — gerekli paketler" "${missing[@]}"
# 💾 tam yedek .rar olsun diye (Ubuntu'da multiverse'te; yoksa uygulama .zip yapar)
if ! command -v rar >/dev/null 2>&1 && [ "$pm" = "apt-get" ]; then
  sudo_once || true
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq rar unrar >>"$LOG" 2>&1 || echo -e "${Y}ℹ rar kurulamadı — yedekler .zip olarak alınır${R}"
fi
# 🔒 yalıtım: Ubuntu 24.04+ AppArmor kullanıcı ad alanlarını kısıtlar → bubblewrap'a izin profili
if command -v bwrap >/dev/null 2>&1 && ! bwrap --ro-bind / / --unshare-user-try --unshare-pid --dev /dev --proc /proc true 2>/dev/null; then
  if [ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" = "1" ] && [ -d /etc/apparmor.d ] && command -v apparmor_parser >/dev/null 2>&1; then
    echo -e "${Y}🔒 Yalıtım için bubblewrap'a AppArmor izni veriliyor (sadece /usr/bin/bwrap)…${R}"
    sudo_once || true
    printf '%s\n' 'abi <abi/4.0>,' 'include <tunables/global>' 'profile cyphertool-bwrap /usr/bin/bwrap flags=(unconfined) {' '  userns,' '  include if exists <local/cyphertool-bwrap>' '}' \
      | sudo tee /etc/apparmor.d/cyphertool-bwrap >/dev/null && sudo apparmor_parser -r /etc/apparmor.d/cyphertool-bwrap 2>/dev/null \
      && echo -e "${G}✔ Yalıtım hazır${R}" || echo -e "${Y}⚠ Yalıtım izni verilemedi — araçlar yalıtımsız çalışır${R}"
  else
    echo -e "${Y}⚠ bubblewrap bu sistemde çalışmıyor — araçlar yalıtımsız çalışır${R}"
  fi
fi
# uygulama içi tarayıcı (yapay zekânın internette gezinmesi için Chrome/Chromium gerekir)
if ! command -v google-chrome >/dev/null 2>&1 && ! command -v google-chrome-stable >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1 \
   && ! command -v chromium-browser >/dev/null 2>&1 && ! command -v brave-browser >/dev/null 2>&1 && ! command -v microsoft-edge >/dev/null 2>&1; then
  echo -e "${Y}🌐 Tarayıcı kuruluyor (Google Chrome — yaklaşık 110 MB)…${R}"
  sudo_once || true; pm_update
  ARCH="$(uname -m)"; T_="$(mktemp -d)"; done_=0
  if [ "$pm" = "apt-get" ] && [ "$ARCH" = "x86_64" ]; then
    run_step "Chrome indiriliyor" curl -fL --progress-bar -o "$T_/chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
      && run_step "Chrome kuruluyor" $SUDO $SENV apt-get install $APTO "$T_/chrome.deb" && done_=1
  elif [ "$pm" = "dnf" ] && [ "$ARCH" = "x86_64" ]; then
    run_step "Chrome kuruluyor" $SUDO dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm && done_=1
  fi
  [ $done_ -eq 0 ] && { run_step "Chromium kuruluyor" inst chromium || run_step "Chromium kuruluyor" inst chromium-browser; } && done_=1
  rm -rf "$T_"
  [ $done_ -eq 1 ] && echo -e "  ${G}✔${R} Tarayıcı kuruldu" || echo -e "  ${Y}⚠ Tarayıcı kurulamadı — Sistem sekmesinden ya da elle kur. Günlük: $LOG${R}"
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

# ── eski Cypher Tool'u kapat (daha önce sudo ile/yönetici olarak başlatılmış olanlar dahil) ──
ct_pids() {   # sadece Cypher Tool'un python süreçleri (bu betiği ya da komut satırında adı geçen kabukları değil)
  for p_ in $(pgrep -f 'cyphertool\.py' 2>/dev/null); do
    [ "$p_" = "$$" ] && continue; [ "$p_" = "$PPID" ] && continue
    a0="$(tr '\0' '\n' < /proc/$p_/cmdline 2>/dev/null | head -n1)"
    case "$(basename "$a0" 2>/dev/null)" in python*) echo "$p_" ;; esac
  done
}
for p_ in $(ct_pids); do kill "$p_" 2>/dev/null || true; done; sleep 1
if [ -n "$(ct_pids)" ]; then
  echo -e "${Y}⚠ Eski Cypher Tool yönetici (root) olarak çalışıyor — kapatmak için yönetici şifresi gerekiyor.${R}"
  sudo_once && sudo kill $(ct_pids) 2>/dev/null || true; sleep 1
fi
# ── daha önce sudo ile kurulduysa dosyalar root'a ait kalmış olabilir → sahipliği kullanıcıya geri ver (yoksa güncelleme yazılamaz) ──
for d in "$HOME/.local" "$HOME/.local/share" "$HOME/.config" "$HOME/.cache"; do   # üst klasörler (yalnızca klasörün kendisi)
  if [ -d "$d" ] && [ "$(stat -c %u "$d" 2>/dev/null)" != "$(id -u)" ]; then
    echo -e "${Y}🔧 $d yöneticiye (root) ait — sahipliği sana veriliyor…${R}"; sudo_once && sudo chown "$(id -u)":"$(id -g)" "$d" || true
  fi
done
for d in "$APP_HOME" "$HOME/.config/cyphertool" "$HOME/CypherTool" "$BIN" "$HOME/.local/share/applications" "$HOME/.cache/cyphertool"; do
  if [ -e "$d" ] && [ -n "$(find "$d" -maxdepth 4 ! -user "$(id -u)" -print -quit 2>/dev/null)" ]; then
    echo -e "${Y}🔧 $d içinde yöneticiye (root) ait dosyalar var — sahipliği sana veriliyor…${R}"
    sudo_once && sudo chown -R "$(id -u)":"$(id -g)" "$d" || echo -e "${Y}  ✖ Değiştirilemedi: sudo chown -R $USER: $d${R}"
  fi
done

mkdir -p "$APP_HOME" "$BIN" "$HOME/.local/share/applications"
rm -rf "$APP_HOME/web"   # eski arayüz dosyaları kalmasın
cp -r "$SRC/cyphertool.py" "$SRC/catalog.json" "$SRC/web" "$APP_HOME/"
[ -f "$SRC/hata_bankasi.json" ] && cp "$SRC/hata_bankasi.json" "$APP_HOME/"
[ -f "$SRC/README.md" ] && cp "$SRC/README.md" "$APP_HOME/"
chmod +x "$APP_HOME/cyphertool.py"
NEWV="$(grep -m1 '^VERSION' "$SRC/cyphertool.py" | cut -d'"' -f2)"; GOTV="$(grep -m1 '^VERSION' "$APP_HOME/cyphertool.py" | cut -d'"' -f2)"
if [ "$NEWV" != "$GOTV" ]; then echo -e "${Y}✖ Dosyalar güncellenemedi (kurulu: $GOTV, yeni: $NEWV). Şunu dene: sudo chown -R $USER: $APP_HOME  ve kurulumu tekrar çalıştır.${R}"; exit 1; fi
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
