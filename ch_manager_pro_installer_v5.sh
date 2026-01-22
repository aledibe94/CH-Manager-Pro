#!/bin/bash

# --- CONFIGURAZIONE ---
APP_NAME="CH Manager Pro"
NEW_VERSION_TAG="5.0"

# PERCORSI
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_ICONS="$SCRIPT_DIR/icons"
INSTALL_DIR="$HOME/.local/share/ch_manager"
DEST_ICONS="$INSTALL_DIR/icons"
SCRIPT_FILE="$INSTALL_DIR/ch_manager_pro.py"
VERSION_FILE="$INSTALL_DIR/version.txt"
CONFIG_FILE="$INSTALL_DIR/config.ini"
DESKTOP_FILE="$HOME/.local/share/applications/ch-manager-pro.desktop"
LOCAL_BIN="$HOME/.local/bin"

# CHECK ZENITY
if ! command -v zenity &> /dev/null; then echo "Errore: Zenity mancante."; exit 1; fi

# --- 1. VERIFICA ASSET ---
if [ ! -d "$SOURCE_ICONS" ]; then
    zenity --error --title="Errore" --text="Cartella 'icons' non trovata!" --width=400
    exit 1
fi

# --- 2. RILEVAMENTO VERSIONE ---
MODE="INSTALL"
CURRENT_VER="Nessuna"

if [ -d "$INSTALL_DIR" ]; then
    if [ -f "$VERSION_FILE" ]; then CURRENT_VER=$(cat "$VERSION_FILE"); else CURRENT_VER="Legacy"; fi

    ACTION=$(zenity --list --radiolist \
        --title="Aggiornamento $APP_NAME" \
        --text="Versione attuale: <b>$CURRENT_VER</b>\nRipristino versione: <b>$NEW_VERSION_TAG</b> (Stable)" \
        --column="" --column="Azione" --column="Descrizione" \
        TRUE "AGGIORNA" "Mantiene impostazioni" \
        FALSE "PULISCI" "Reinstalla da zero" \
        --width=500 --height=280)

    if [ $? -ne 0 ]; then exit 1; fi
    if [ "$ACTION" == "AGGIORNA" ]; then MODE="UPDATE"; elif [ "$ACTION" == "PULISCI" ]; then MODE="CLEAN"; fi
else
    zenity --info --title="Installazione" --text="Installazione $APP_NAME V$NEW_VERSION_TAG\n(Versione Stabile)" --width=350
fi

# --- 3. INSTALLAZIONE ---
(
    echo "10"; echo "# ⚙️ Preparazione..."
    rm -rf "$HOME/scripts/ch_manager"

    if [ "$MODE" == "CLEAN" ]; then
        rm -rf "$INSTALL_DIR"; mkdir -p "$INSTALL_DIR"
    elif [ "$MODE" == "UPDATE" ]; then
        if [ -f "$CONFIG_FILE" ]; then cp "$CONFIG_FILE" "/tmp/ch_manager_config.bak"; fi
        rm -f "$SCRIPT_FILE" "$DESKTOP_FILE" "$VERSION_FILE"
        rm -rf "$DEST_ICONS"
        mkdir -p "$INSTALL_DIR"
    else
        mkdir -p "$INSTALL_DIR"
    fi
    mkdir -p "$LOCAL_BIN"
    sleep 1

    echo "30"; echo "# 📦 Dipendenze..."
    if ! command -v unrar &> /dev/null && [ ! -f "$LOCAL_BIN/unrar" ]; then
        cd "$INSTALL_DIR"
        wget -qO unrar.tar.gz https://www.rarlab.com/rar/rarlinux-x64.tar.gz
        tar -xzf unrar.tar.gz --wildcards '*/unrar' --strip-components=1
        mv unrar "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/unrar"
        rm unrar.tar.gz
    fi

    echo "50"; echo "# 🎨 Copia risorse..."
    cp -r "$SOURCE_ICONS" "$INSTALL_DIR/"

    DESKTOP_ICON_PATH=""
    if [ -f "$DEST_ICONS/icon.png" ]; then DESKTOP_ICON_PATH="$DEST_ICONS/icon.png";
    elif [ -f "$DEST_ICONS/icon.webp" ]; then DESKTOP_ICON_PATH="$DEST_ICONS/icon.webp";
    else DESKTOP_ICON_PATH="input-gaming"; fi

    echo "70"; echo "# 📝 Scrittura Codice V$NEW_VERSION_TAG..."
cat << 'EOF' > "$SCRIPT_FILE"
import sys
import os
import time
import threading
import shutil
import subprocess
import configparser
import locale
import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, GLib, Gio, Adw, GdkPixbuf

# --- VERSIONE E TRADUZIONI ---
APP_VERSION = "5.0"

LANG_DATA = {
    "en": {
        "title": "CH Manager",
        "lbl_ver": "Version {}",
        "tab_auto": "Automation",
        "tab_lib": "Library",
        "grp_mon": "Monitoring",
        "grp_tools": "Tools",
        "mon_title": "Download Monitor",
        "mon_sub_on": "Active - Watching folder...",
        "mon_sub_off": "Paused",
        "game_title": "In-Game Mode",
        "game_sub": "Install while playing",
        "btn_import": "Import Files",
        "btn_backup": "Open Backup",
        "btn_clean_songs": "Manage Songs",
        "btn_clean_arch": "Manage Archives",
        "btn_path": "Backup Path",
        "toast_imported": "Imported {} files",
        "toast_removed": "Removed {} items",
        "toast_path": "Path updated",
        "notif_install": "Installed",
        "notif_scan": "Run 'Scan Songs' in game!",
        "notif_threat": "Threat Detected",
        "notif_exe": "Executable removed.",
        "search_ph": "Filter...",
        "btn_all": "Select All",
        "btn_del": "Delete",
        "dialog_conf": "Confirm",
        "dialog_del_body": "Delete {} items?",
        "btn_cancel": "Cancel",
        "btn_lib_only": "Library Only",
        "btn_lib_back": "Library + Backup"
    },
    "it": {
        "title": "CH Manager",
        "lbl_ver": "Versione {}",
        "tab_auto": "Automazione",
        "tab_lib": "Libreria",
        "grp_mon": "Monitoraggio",
        "grp_tools": "Strumenti",
        "mon_title": "Monitor Download",
        "mon_sub_on": "Attivo - In attesa...",
        "mon_sub_off": "In Pausa",
        "game_title": "Modalità In-Game",
        "game_sub": "Installa a gioco aperto",
        "btn_import": "Importa File",
        "btn_backup": "Apri Backup",
        "btn_clean_songs": "Gestisci Canzoni",
        "btn_clean_arch": "Gestisci Archivio",
        "btn_path": "Percorso Backup",
        "toast_imported": "Importati {} file",
        "toast_removed": "Rimossi {} elementi",
        "toast_path": "Percorso aggiornato",
        "notif_install": "Installato",
        "notif_scan": "Esegui 'Scan Songs' nel gioco!",
        "notif_threat": "Minaccia Rilevata",
        "notif_exe": "File eseguibile rimosso.",
        "search_ph": "Filtra...",
        "btn_all": "Seleziona Tutto",
        "btn_del": "Elimina",
        "dialog_conf": "Conferma",
        "dialog_del_body": "Eliminare {} elementi?",
        "btn_cancel": "Annulla",
        "btn_lib_only": "Solo Libreria",
        "btn_lib_back": "Libreria + Backup"
    }
}

try:
    SYS_LANG = locale.getdefaultlocale()[0]
    CURRENT_LANG = "it" if "it" in str(SYS_LANG).lower() else "en"
except: CURRENT_LANG = "en"

def tr(key): return LANG_DATA[CURRENT_LANG].get(key, f"[{key}]")

# --- CONFIGURAZIONE ---
APP_ID = "com.clonehero.manager"
BASE_DIR = os.path.expanduser("~/.local/share/ch_manager")
ICONS_DIR = os.path.join(BASE_DIR, "icons")
CONFIG_FILE = os.path.join(BASE_DIR, "config.ini")
GAME_DIR = os.path.expanduser("~/.clonehero/Songs")
SANDBOX_DIR = f"/tmp/ch_sandbox_{os.environ.get('USER')}"
SYSTEM_DL_DIR = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DOWNLOAD) or os.path.expanduser("~/Downloads")

SPLASH_IMG = os.path.join(ICONS_DIR, "splash.png")
if not os.path.exists(SPLASH_IMG): SPLASH_IMG = os.path.join(ICONS_DIR, "splash.webp")

local_bin = os.path.expanduser("~/.local/bin")
if local_bin not in os.environ["PATH"]: os.environ["PATH"] += os.pathsep + local_bin

os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(GAME_DIR, exist_ok=True)

class CHManagerApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.config = configparser.ConfigParser()
        self.monitoring = False
        self.backup_dir = ""
        self.install_while_open = True
        self.load_config()
        self.connect('startup', self.on_startup)
        self.connect('activate', self.on_activate)

    def load_config(self):
        self.config.read(CONFIG_FILE)
        self.backup_dir = self.config.get("DEFAULT", "BackupDir", fallback=os.path.expanduser("~/CloneHero_Archive"))
        self.install_while_open = self.config.getboolean("DEFAULT", "InstallWhileOpen", fallback=True)
        if not os.path.exists(self.backup_dir): os.makedirs(self.backup_dir, exist_ok=True)
        self.save_config()

    def save_config(self):
        self.config["DEFAULT"] = {"BackupDir": self.backup_dir, "InstallWhileOpen": str(self.install_while_open)}
        with open(CONFIG_FILE, 'w') as f: self.config.write(f)

    def on_startup(self, app):
        style_manager = Adw.StyleManager.get_default()
        style_manager.set_color_scheme(Adw.ColorScheme.PREFER_DARK)

    def on_activate(self, app):
        if not app.get_active_window():
            self.splash = SplashScreen(self)
            self.splash.present()
            GLib.timeout_add(2500, self.switch_to_main)

    def switch_to_main(self):
        if self.splash: self.splash.close()
        win = MainWindow(self)
        win.present()
        return False

    def is_game_running(self):
        try: return bool(subprocess.check_output(["pgrep", "-f", "-i", "clonehero"], stderr=subprocess.DEVNULL).strip())
        except: return False

    def send_notification(self, title, body):
        for cmd in [["kdialog", "--title", title, "--passivepopup", body, "4"], ["notify-send", "-i", "input-gaming", title, body], ["zenity", "--notification", "--text", f"{title}: {body}"]]:
            if shutil.which(cmd[0]): subprocess.Popen(cmd, stderr=subprocess.DEVNULL); break

class SplashScreen(Gtk.Window):
    def __init__(self, app):
        super().__init__(application=app, title="Splash")
        self.set_decorated(False)
        self.set_default_size(500, 320)
        self.set_modal(True)

        picture = Gtk.Picture()
        if os.path.exists(SPLASH_IMG):
            picture.set_filename(SPLASH_IMG)
        else:
            picture.set_icon_name("image-missing-symbolic")

        picture.set_content_fit(Gtk.ContentFit.COVER)

        self.set_child(picture)

class MainWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title=tr("title"))
        self.app = app
        self.set_default_size(480, 680)
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        header = Adw.HeaderBar()
        self.stack = Adw.ViewStack()

        # FORZA ESPANSIONE
        self.stack.set_vexpand(True)
        self.stack.set_valign(Gtk.Align.FILL)

        switcher = Adw.ViewSwitcherTitle(stack=self.stack, title=tr("title"))
        header.set_title_widget(switcher)
        main_box.append(header)

        self.setup_automation_tab(); self.setup_library_tab()
        main_box.append(self.stack)

        # FOOTER
        ver_label = Gtk.Label(label=tr("lbl_ver").format(APP_VERSION))
        ver_label.add_css_class("caption")
        ver_label.add_css_class("dim-label")
        ver_label.set_halign(Gtk.Align.START)
        ver_label.set_valign(Gtk.Align.END)
        ver_label.set_margin_start(20)
        ver_label.set_margin_bottom(15)
        main_box.append(ver_label)

        self.set_content(main_box)

    def setup_automation_tab(self):
        page = Adw.PreferencesPage()
        grp = Adw.PreferencesGroup(title=tr("grp_mon"))
        page.add(grp)
        self.status_row = Adw.ActionRow(title=tr("mon_title"), subtitle=tr("mon_sub_off"))
        self.status_row.set_icon_name("folder-download-symbolic")
        self.switch = Gtk.Switch(); self.switch.set_valign(Gtk.Align.CENTER)
        self.switch.connect("state-set", self.on_monitor_toggle)
        self.status_row.add_suffix(self.switch); grp.add(self.status_row)
        self.game_row = Adw.ActionRow(title=tr("game_title"), subtitle=tr("game_sub"))
        self.game_row.set_icon_name("input-gaming-symbolic")
        self.sw_game = Gtk.Switch(); self.sw_game.set_active(self.app.install_while_open); self.sw_game.set_valign(Gtk.Align.CENTER)
        self.sw_game.connect("state-set", self.on_game_config_toggle)
        self.game_row.add_suffix(self.sw_game); grp.add(self.game_row)
        p = self.stack.add_titled(page, "auto", tr("tab_auto")); p.set_icon_name("preferences-system-time-symbolic")

    def setup_library_tab(self):
        page = Adw.PreferencesPage()
        grp = Adw.PreferencesGroup(title=tr("grp_tools"))
        page.add(grp)
        def add_row(t, i, cb):
            r = Adw.ActionRow(title=t); r.set_icon_name(i); r.set_activatable(True)
            r.connect("activated", cb); r.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic")); grp.add(r)
        add_row(tr("btn_import"), "list-add-symbolic", self.on_import_clicked)
        add_row(tr("btn_backup"), "folder-documents-symbolic", self.on_open_backup)
        add_row(tr("btn_clean_songs"), "edit-clear-symbolic", self.on_clean_songs)
        add_row(tr("btn_clean_arch"), "user-trash-symbolic", self.on_clean_archive)
        add_row(tr("btn_path"), "drive-harddisk-symbolic", self.on_change_backup)
        p = self.stack.add_titled(page, "lib", tr("tab_lib")); p.set_icon_name("library-music-symbolic")

    def on_game_config_toggle(self, switch, state):
        self.app.install_while_open = state; self.app.save_config(); return True
    def on_monitor_toggle(self, switch, state):
        self.app.monitoring = state
        if state:
            self.status_row.set_subtitle(tr("mon_sub_on")); subprocess.Popen(["xdg-open", "https://enchor.us/"], stderr=subprocess.DEVNULL)
            threading.Thread(target=self.monitor_loop, daemon=True).start()
        else: self.status_row.set_subtitle(tr("mon_sub_off")); return True

    def monitor_loop(self):
        last_check_game = 0; game_running = False
        while self.app.monitoring:
            if time.time() - last_check_game > 5: game_running = self.app.is_game_running(); last_check_game = time.time()
            try:
                files = [f for f in os.listdir(SYSTEM_DL_DIR) if f.lower().endswith(('.zip', '.rar', '.7z'))]
                for f in files:
                    fp = os.path.join(SYSTEM_DL_DIR, f)
                    if ".part" in f or ".crdownload" in f: continue
                    if game_running and not self.app.install_while_open: continue
                    try:
                        s1 = os.path.getsize(fp); time.sleep(1); s2 = os.path.getsize(fp)
                        if s1 == s2 and s1 > 0:
                            if self.secure_install(fp):
                                shutil.move(fp, os.path.join(self.app.backup_dir, f))
                                if game_running: GLib.idle_add(self.app.send_notification, tr("notif_install"), tr("notif_scan"))
                                else: GLib.idle_add(self.app.send_notification, tr("notif_install"), f"{f}")
                                GLib.idle_add(self.show_toast, tr("notif_install"))
                    except: pass
            except: pass
            time.sleep(2)

    def secure_install(self, source_file):
        filename = os.path.basename(source_file); dirname = os.path.splitext(filename)[0]
        if os.path.exists(SANDBOX_DIR): shutil.rmtree(SANDBOX_DIR)
        os.makedirs(SANDBOX_DIR)
        cmd = []
        if filename.endswith('.zip'): cmd = ["unzip", "-oq", source_file, "-d", SANDBOX_DIR]
        elif filename.endswith('.rar'): cmd = ["unrar", "x", "-o+", "-inul", source_file, f"{SANDBOX_DIR}/"]
        elif filename.endswith('.7z'): cmd = ["7z", "x", source_file, f"-o{SANDBOX_DIR}/", "-y"]
        if not cmd or subprocess.call(cmd) != 0: return False
        has_chart = False
        for root, dirs, files in os.walk(SANDBOX_DIR):
            for f in files:
                if f.endswith(('.exe', '.bat', '.sh')): GLib.idle_add(self.app.send_notification, tr("notif_threat"), tr("notif_exe")); shutil.rmtree(SANDBOX_DIR); return False
                if f.endswith(('song.ini', '.chart', '.mid')): has_chart = True
        if not has_chart: shutil.rmtree(SANDBOX_DIR); return False
        target_path = os.path.join(GAME_DIR, dirname); root_files = [f for f in os.listdir(SANDBOX_DIR) if os.path.isfile(os.path.join(SANDBOX_DIR, f))]
        if root_files: os.makedirs(target_path, exist_ok=True); [shutil.move(os.path.join(SANDBOX_DIR, i), target_path) for i in os.listdir(SANDBOX_DIR)]
        else: [shutil.move(os.path.join(SANDBOX_DIR, i), GAME_DIR) for i in os.listdir(SANDBOX_DIR)]
        shutil.rmtree(SANDBOX_DIR); return True

    def show_toast(self, message): self.add_toast(Adw.Toast(title=message))
    def on_open_backup(self, _): subprocess.Popen(["xdg-open", self.app.backup_dir])
    def on_import_clicked(self, _): d = Gtk.FileDialog(title=tr("btn_import")); f = Gtk.FileFilter(); f.set_name("Archivi"); f.add_pattern("*.zip"); f.add_pattern("*.rar"); f.add_pattern("*.7z"); d.set_default_filter(f); d.open_multiple(self, None, self.on_files_selected)
    def on_files_selected(self, d, res):
        try:
            files = d.open_multiple_finish(res); c = 0
            for f in files:
                if self.secure_install(f.get_path()): shutil.move(f.get_path(), os.path.join(self.app.backup_dir, os.path.basename(f.get_path()))); c += 1
            self.show_toast(tr("toast_imported").format(c))
        except: pass
    def on_change_backup(self, _): d = Gtk.FileDialog(); d.select_folder(self, None, self.on_folder_selected)
    def on_folder_selected(self, d, res):
        try:
            f = d.select_folder_finish(res)
            if f: self.app.backup_dir = f.get_path(); self.app.save_config(); self.show_toast(tr("toast_path"))
        except: pass
    def on_clean_songs(self, _): self.show_checklist(tr("btn_clean_songs"), GAME_DIR, True, True)
    def on_clean_archive(self, _): self.show_checklist(tr("btn_clean_arch"), self.app.backup_dir, False, False)
    def show_checklist(self, title, base_path, is_dir, can_delete_backup=False):
        win = Gtk.Window(title=title, transient_for=self, modal=True, default_width=450, default_height=600)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10); box.set_margin_top(10); box.set_margin_bottom(10); box.set_margin_start(10); box.set_margin_end(10)
        search_entry = Gtk.SearchEntry(placeholder_text=tr("search_ph")); box.append(search_entry)
        btn_select_all = Gtk.Button(label=tr("btn_all")); box.append(btn_select_all)
        lb = Gtk.ListBox(); lb.set_selection_mode(Gtk.SelectionMode.NONE); lb.add_css_class("boxed-list")
        try:
            for item in sorted(os.listdir(base_path)):
                fp = os.path.join(base_path, item)
                if (is_dir and os.path.isdir(fp)) or (not is_dir and os.path.isfile(fp)):
                    row = Gtk.ListBoxRow(); chk = Gtk.CheckButton(label=item); chk.set_margin_start(10); row.set_child(chk); row.item_name = item; row.checkbox = chk; lb.append(row)
        except: pass
        scroll = Gtk.ScrolledWindow(child=lb, vexpand=True); box.append(scroll)
        def on_search_changed(entry):
            query = entry.get_text().strip().lower(); c = lb.get_first_child()
            while c:
                if hasattr(c, 'item_name'): c.set_visible(query in c.item_name.lower())
                c = c.get_next_sibling()
        search_entry.connect('search-changed', on_search_changed)
        def on_toggle_all(btn):
            c = lb.get_first_child()
            while c:
                if c.get_visible(): c.checkbox.set_active(True)
                c = c.get_next_sibling()
        btn_select_all.connect("clicked", on_toggle_all)
        btn_del = Gtk.Button(label=tr("btn_del")); btn_del.add_css_class("destructive-action")
        def execute_delete(delete_backup_also):
            c = lb.get_first_child(); rem = []; count = 0
            while c:
                if hasattr(c, 'checkbox') and c.checkbox.get_active() and c.get_visible():
                    fp = os.path.join(base_path, c.item_name)
                    try:
                        if os.path.isdir(fp): shutil.rmtree(fp)
                        else: os.remove(fp)
                        rem.append(c); count += 1
                        if delete_backup_also:
                            for ext in ['.zip', '.rar', '.7z']:
                                ap = os.path.join(self.app.backup_dir, c.item_name + ext);
                                if os.path.exists(ap): os.remove(ap)
                    except: pass
                c = c.get_next_sibling()
            for r in rem: lb.remove(r)
            self.show_toast(tr("toast_removed").format(count));
            if count > 0: win.close()
        def on_delete_clicked(_):
            cnt = 0; c = lb.get_first_child()
            while c:
                if hasattr(c, 'checkbox') and c.checkbox.get_active() and c.get_visible(): cnt += 1
                c = c.get_next_sibling()
            if cnt == 0: return
            if can_delete_backup:
                d = Adw.MessageDialog(transient_for=win, heading=tr("dialog_conf"), body=tr("dialog_del_body").format(cnt))
                d.add_response("cancel", tr("btn_cancel")); d.add_response("lib_only", tr("btn_lib_only")); d.add_response("all", tr("btn_lib_back"))
                d.set_response_appearance("all", Adw.ResponseAppearance.DESTRUCTIVE)
                d.connect("response", lambda d, r: (execute_delete(r=="all") if r!="cancel" else None, d.close()))
                d.present()
            else: execute_delete(False)
        btn_del.connect("clicked", on_delete_clicked)
        box.append(btn_del); win.set_child(box); win.present()

if __name__ == "__main__":
    app = CHManagerApp()
    app.run(sys.argv)
EOF

    echo "$NEW_VERSION_TAG" > "$VERSION_FILE"
    if [ "$MODE" == "UPDATE" ] && [ -f "/tmp/ch_manager_config.bak" ]; then
        echo "80"; echo "# ♻️ Ripristino impostazioni..."
        mv "/tmp/ch_manager_config.bak" "$CONFIG_FILE"
    fi

    echo "90"; echo "# 🚀 Finalizzazione..."
cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=$APP_NAME
Comment=Gestore Libreria per Clone Hero
Exec=python3 "$SCRIPT_FILE"
Icon=$DESKTOP_ICON_PATH
Terminal=false
Type=Application
Categories=Game;Utility;
StartupNotify=true
StartupWMClass=com.clonehero.manager
EOF

    chmod +x "$SCRIPT_FILE"
    chmod +x "$DESKTOP_FILE"
    chmod +x "$LOCAL_BIN/unrar" 2>/dev/null
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null

    echo "100"; echo "# ✅ Completato!"
    sleep 2

) | zenity --progress \
  --title="Installazione $APP_NAME" \
  --text="Avvio..." \
  --percentage=0 \
  --auto-close \
  --width=350

if [ $? -eq 0 ]; then
    zenity --info --title="Successo" --text="$APP_NAME V$NEW_VERSION_TAG installato!" --width=300
fi
