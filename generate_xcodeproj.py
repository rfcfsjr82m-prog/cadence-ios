#!/usr/bin/env python3
"""
Generates Interval.xcodeproj/project.pbxproj — Xcode 26 compatible (objectVersion 77).
Run: python3 generate_xcodeproj.py
"""

import os, hashlib

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ_DIR = os.path.join(ROOT, "Interval.xcodeproj")
os.makedirs(PROJ_DIR, exist_ok=True)

def uid(seed):
    return hashlib.md5(seed.encode()).hexdigest().upper()[:24]

# ── File lists ────────────────────────────────────────────────────────────────
SOURCES = [
    ("IntervalApp.swift",         "Interval/App"),
    ("AppState.swift",            "Interval/App"),
    ("HealthKitManager.swift",    "Interval/App"),
    ("AudioSettings.swift",       "Interval/App"),
    ("WatchSyncManager.swift",    "Interval/App"),
    ("TimerConfig.swift",         "Interval/Models"),
    ("PersistedSession.swift",    "Interval/Models"),
    ("Presets.swift",             "Interval/Models"),
    ("TrainingProtocol.swift",    "Interval/Models"),
    ("LibraryView.swift",         "Interval/Views/Library"),
    ("TimerCard.swift",           "Interval/Views/Library"),
    ("FilterPillsView.swift",     "Interval/Views/Library"),
    ("ProtocolCard.swift",        "Interval/Views/Library"),
    ("ProtocolDetailView.swift",  "Interval/Views/Library"),
    ("ConfigureSequenceView.swift","Interval/Views/Wizard"),
    ("BlockEditorSheet.swift",    "Interval/Views/Wizard"),
    ("SoundPickerSheet.swift",    "Interval/Views/Wizard"),
    ("OpeningClosingView.swift",  "Interval/Views/Wizard"),
    ("ActiveTimerView.swift",     "Interval/Views/Timer"),
    ("RingsView.swift",           "Interval/Views/Timer"),
    ("CountdownOverlay.swift",    "Interval/Views/Timer"),
    ("SessionDoneOverlay.swift",  "Interval/Views/Timer"),
    ("ShareCardView.swift",       "Interval/Views/Timer"),
    ("LocationPickerSheet.swift", "Interval/Views/Timer"),
    ("SettingsView.swift",        "Interval/Views/Settings"),
    ("SoundEngine.swift",         "Interval/Audio"),
    ("VoiceEngine.swift",         "Interval/Audio"),
    ("HapticEngine.swift",        "Interval/Audio"),
    ("FlashlightEngine.swift",    "Interval/Audio"),
    ("ColorPalette.swift",        "Interval/Utilities"),
    ("TimeFormatter.swift",       "Interval/Utilities"),
    ("TimerSearch.swift",         "Interval/Utilities"),
    ("SwipeToDelete.swift",       "Interval/Utilities"),
    ("KeyboardDismiss.swift",     "Interval/Utilities"),
    ("LocationManager.swift",     "Interval/Utilities"),
    ("CadenceActivityAttributes.swift", "Interval/Models"),
    ("SessionHistoryEntry.swift",       "Interval/Models"),
    ("FeatureFlags.swift",              "Interval/Utilities"),
    ("SharedDefaults.swift",            "Interval/Utilities"),
    ("AllTimersSync.swift",             "Interval/Utilities"),
]

# Widget Extension source files
# WIDGET_OWN = files that live in CadenceWidget/ (shown in navigator under that group)
# WIDGET_SHARED = files from Interval/ compiled into the widget but displayed in their own group
WIDGET_OWN = [
    ("CadenceWidget.swift",              "CadenceWidget"),
    ("CadenceActivityAttributes.swift",  "CadenceWidget"),
    ("PinnedTimersWidget.swift",         "CadenceWidget"),
    ("TimerWidgetEntity.swift",          "CadenceWidget"),
]
WIDGET_SHARED = [
    ("SharedDefaults.swift",             "Interval/Utilities"),
]
WIDGET_SOURCES = WIDGET_OWN + WIDGET_SHARED

# Watch App source files
# WATCH_OWN = files that live in CadenceWatch/ (shown in navigator under that group)
# WATCH_SHARED = files from Interval/ compiled into the watch but displayed in their own group
WATCH_OWN = [
    ("CadenceWatchApp.swift",            "CadenceWatch"),
    ("WatchTimerEngine.swift",           "CadenceWatch"),
    ("WatchSoundEngine.swift",           "CadenceWatch"),
    ("WatchConnectivityManager.swift",   "CadenceWatch"),
    ("TimerListView.swift",              "CadenceWatch/Views"),
    ("WatchActiveTimerView.swift",       "CadenceWatch/Views"),
    ("ProgramDetailView.swift",          "CadenceWatch/Views"),
]
WATCH_SHARED = [
    ("TimerConfig.swift",            "Interval/Models"),
    ("Presets.swift",                "Interval/Models"),
    ("TrainingProtocol.swift",       "Interval/Models"),
    ("SharedDefaults.swift",         "Interval/Utilities"),
    ("AllTimersSync.swift",          "Interval/Utilities"),
    ("ColorPalette.swift",           "Interval/Utilities"),
    ("TimeFormatter.swift",          "Interval/Utilities"),
]
WATCH_SOURCES = WATCH_OWN + WATCH_SHARED

WATCH_RESOURCES = [
    ("Assets.xcassets",  "CadenceWatch"),
]

RESOURCES = [
    ("Assets.xcassets",              "Interval/Resources"),
    ("Beacon.wav",                   "Interval/Resources"),
    ("Bell Gentle.wav",              "Interval/Resources"),
    ("Bell Reverb.mp3",              "Interval/Resources"),
    ("Bell.wav",                     "Interval/Resources"),
    ("Bleep.wav",                    "Interval/Resources"),
    ("Gong.wav",                     "Interval/Resources"),
    ("Sonar High.wav",               "Interval/Resources"),
    ("Sonar Low.wav",                "Interval/Resources"),
    ("Sonar Ping.wav",               "Interval/Resources"),
    ("Tick.wav",                     "Interval/Resources"),
    ("Tock.wav",                     "Interval/Resources"),
    ("Boxing Bell.wav",              "Interval/Resources"),
    ("Voice_Female_Start.mp3",       "Interval/Resources/soundfx"),
    ("Voice_Female_Finsih.mp3",      "Interval/Resources/soundfx"),
    ("Voice_Male_Start.mp3",         "Interval/Resources/soundfx"),
    ("Voice_Male_Finish.mp3",        "Interval/Resources/soundfx"),
    ("Voice_Male_Running.mp3",                    "Interval/Resources/soundfx"),
    ("Voice_Male_Walking.mp3",                    "Interval/Resources/soundfx"),
    ("Voice_Male_Warming-up.mp3",                 "Interval/Resources/soundfx"),
    ("Voice_Male_You're Halfway through.mp3",     "Interval/Resources/soundfx"),
]

# Audio files shared from the iOS bundle into the Watch bundle (excludes Assets.xcassets)
WATCH_AUDIO_RESOURCES = [
    (n, d) for n, d in RESOURCES
    if d in ("Interval/Resources", "Interval/Resources/soundfx")
    and n != "Assets.xcassets"
]

ALL_FILES    = SOURCES + RESOURCES
ALL_WIDGET   = WIDGET_SOURCES
ALL_WATCH    = WATCH_SOURCES + WATCH_RESOURCES

def file_type(name):
    ext = os.path.splitext(name)[1].lower()
    if ext == ".xcassets": return "folder.assetcatalog"
    return {".swift": "sourcecode.swift", ".wav": "audio.wav", ".mp3": "audio.mpeg"}.get(ext, "file")

def needs_quotes(s):
    import re
    return bool(re.search(r'[\s\(\)\[\]{}<>!\$\*@#%\^&=\|]', s)) or s == ""

def pbx_val(s):
    if needs_quotes(s):
        return f'"{s}"'
    return s

# ── IDs ───────────────────────────────────────────────────────────────────────
PROJECT_ID        = uid("PROJECT")
TARGET_ID         = uid("TARGET")
SOURCES_PHASE     = uid("SOURCES_PHASE")
RESOURCES_PHASE   = uid("RESOURCES_PHASE")
FRAMEWORKS_PHASE  = uid("FRAMEWORKS_PHASE")
PROJ_CFG_LIST     = uid("PROJ_CFG_LIST")
TGT_CFG_LIST      = uid("TGT_CFG_LIST")
PROJ_DEBUG        = uid("PROJ_DEBUG")
PROJ_RELEASE      = uid("PROJ_RELEASE")
TGT_DEBUG         = uid("TGT_DEBUG")
TGT_RELEASE       = uid("TGT_RELEASE")
APP_PRODUCT       = uid("APP_PRODUCT")
GRP_MAIN          = uid("GRP_MAIN")
GRP_PRODUCTS      = uid("GRP_PRODUCTS")
GRP_APP           = uid("GRP_APP")
GRP_MODELS        = uid("GRP_MODELS")
GRP_VIEWS         = uid("GRP_VIEWS")
GRP_LIB           = uid("GRP_LIB")
GRP_WIZARD        = uid("GRP_WIZARD")
GRP_TIMER         = uid("GRP_TIMER")
GRP_AUDIO         = uid("GRP_AUDIO")
GRP_RES           = uid("GRP_RES")
GRP_SOUNDFX       = uid("GRP_SOUNDFX")
GRP_UTIL          = uid("GRP_UTIL")
GRP_INTERVAL      = uid("GRP_INTERVAL")
HEALTHKIT_FW_REF      = uid("HEALTHKIT_FW_REF")
HEALTHKIT_FW_BF       = uid("HEALTHKIT_FW_BF")
WATCHCONN_FW_REF      = uid("WATCHCONN_FW_REF")
WATCHCONN_FW_BF_IOS   = uid("WATCHCONN_FW_BF_IOS")
WATCHCONN_FW_BF_WATCH = uid("WATCHCONN_FW_BF_WATCH")
APPINTENTS_FW_REF     = uid("APPINTENTS_FW_REF")
APPINTENTS_FW_BF_WIDGET = uid("APPINTENTS_FW_BF_WIDGET")
ENTITLEMENTS_REF      = uid("ENTITLEMENTS_REF")

# Widget extension IDs
WIDGET_TARGET_ID      = uid("WIDGET_TARGET")
WIDGET_PRODUCT        = uid("WIDGET_PRODUCT")
WIDGET_SOURCES_PHASE  = uid("WIDGET_SOURCES_PHASE")
WIDGET_FRAMEWORKS_PHASE = uid("WIDGET_FRAMEWORKS_PHASE")
WIDGET_RESOURCES_PHASE  = uid("WIDGET_RESOURCES_PHASE")
WIDGET_CFG_LIST       = uid("WIDGET_CFG_LIST")
WIDGET_DEBUG          = uid("WIDGET_DEBUG")
WIDGET_RELEASE        = uid("WIDGET_RELEASE")
WIDGET_GRP            = uid("WIDGET_GRP")
WIDGET_PRODUCT_REF    = uid("WIDGET_PRODUCT_REF")
WIDGET_ENTITLEMENTS_REF = uid("WIDGET_ENTITLEMENTS_REF")
WIDGET_DEPENDENCY_ID  = uid("WIDGET_DEPENDENCY")   # PBXTargetDependency
WIDGET_PROXY_ID       = uid("WIDGET_PROXY")        # PBXContainerItemProxy
WIDGET_EMBED_PHASE    = uid("WIDGET_EMBED_PHASE")  # Embed App Extensions copy phase
WIDGET_EMBED_BF       = uid("WIDGET_EMBED_BF")     # build file for embedding .appex
WIDGETKIT_FW_REF      = uid("WIDGETKIT_FW_REF")
WIDGETKIT_FW_BF       = uid("WIDGETKIT_FW_BF")
ACTIVITYKIT_FW_REF    = uid("ACTIVITYKIT_FW_REF")
ACTIVITYKIT_FW_BF     = uid("ACTIVITYKIT_FW_BF")
ACTIVITYKIT_MAIN_BF   = uid("ACTIVITYKIT_MAIN_BF")  # ActivityKit in main app target

# Watch App IDs
WATCH_TARGET_ID         = uid("WATCH_TARGET")
WATCH_PRODUCT           = uid("WATCH_PRODUCT")
WATCH_SOURCES_PHASE     = uid("WATCH_SOURCES_PHASE")
WATCH_FRAMEWORKS_PHASE  = uid("WATCH_FRAMEWORKS_PHASE")
WATCH_RESOURCES_PHASE   = uid("WATCH_RESOURCES_PHASE")
WATCH_CFG_LIST          = uid("WATCH_CFG_LIST")
WATCH_DEBUG             = uid("WATCH_DEBUG")
WATCH_RELEASE           = uid("WATCH_RELEASE")
WATCH_GRP               = uid("WATCH_GRP")
WATCH_GRP_VIEWS         = uid("WATCH_GRP_VIEWS")
WATCH_PRODUCT_REF       = uid("WATCH_PRODUCT_REF")
WATCH_ENTITLEMENTS_REF  = uid("WATCH_ENTITLEMENTS_REF")
WATCH_DEPENDENCY_ID     = uid("WATCH_DEPENDENCY")
WATCH_PROXY_ID          = uid("WATCH_PROXY")
WATCH_EMBED_PHASE       = uid("WATCH_EMBED_PHASE")
WATCH_EMBED_BF          = uid("WATCH_EMBED_BF")

# Per-file IDs  (main app + widget + watch together)
_all_files_combined = list({(n, d) for n, d in ALL_FILES + ALL_WIDGET + ALL_WATCH + WATCH_AUDIO_RESOURCES})
fref   = {n + d: uid("FREF_" + n + d) for n, d in _all_files_combined}
bfile  = {n + d: uid("BF_"   + n + d) for n, d in ALL_FILES}
wfile  = {n + d: uid("WBF_"  + n + d) for n, d in ALL_WIDGET}
vfile  = {n + d: uid("VBF_"  + n + d) for n, d in ALL_WATCH}
vafile = {n + d: uid("VAF_"  + n + d) for n, d in WATCH_AUDIO_RESOURCES}
key = lambda name, dir: name + dir

# ── Output buffer ─────────────────────────────────────────────────────────────
out = []
def W(s=""): out.append(s)

W("// !$*UTF8*$!")
W("{")
W("\tarchiveVersion = 1;")
W("\tclasses = {")
W("\t};")
W("\tobjectVersion = 77;")
W("\tobjects = {")
W()

# PBXBuildFile
W("/* Begin PBXBuildFile section */")
for name, dir in ALL_FILES:
    phase = "Sources" if (name, dir) in SOURCES else "Resources"
    W(f"\t\t{bfile[key(name,dir)]} /* {name} in {phase} */ = {{isa = PBXBuildFile; fileRef = {fref[key(name,dir)]} /* {name} */; }};")
W(f"\t\t{HEALTHKIT_FW_BF} /* HealthKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {HEALTHKIT_FW_REF} /* HealthKit.framework */; }};")
W(f"\t\t{ACTIVITYKIT_MAIN_BF} /* ActivityKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ACTIVITYKIT_FW_REF} /* ActivityKit.framework */; }};")
W(f"\t\t{WATCHCONN_FW_BF_IOS} /* WatchConnectivity.framework in Frameworks (iOS) */ = {{isa = PBXBuildFile; fileRef = {WATCHCONN_FW_REF} /* WatchConnectivity.framework */; }};")
W(f"\t\t{WATCHCONN_FW_BF_WATCH} /* WatchConnectivity.framework in Frameworks (Watch) */ = {{isa = PBXBuildFile; fileRef = {WATCHCONN_FW_REF} /* WatchConnectivity.framework */; }};")
W(f"\t\t{APPINTENTS_FW_BF_WIDGET} /* AppIntents.framework in Frameworks (Widget) */ = {{isa = PBXBuildFile; fileRef = {APPINTENTS_FW_REF} /* AppIntents.framework */; }};")
# Widget build files
for name, dir in ALL_WIDGET:
    W(f"\t\t{wfile[key(name,dir)]} /* {name} in Sources (Widget) */ = {{isa = PBXBuildFile; fileRef = {fref[key(name,dir)]} /* {name} */; }};")
W(f"\t\t{WIDGETKIT_FW_BF} /* WidgetKit.framework in Frameworks (Widget) */ = {{isa = PBXBuildFile; fileRef = {WIDGETKIT_FW_REF} /* WidgetKit.framework */; }};")
W(f"\t\t{ACTIVITYKIT_FW_BF} /* ActivityKit.framework in Frameworks (Widget) */ = {{isa = PBXBuildFile; fileRef = {ACTIVITYKIT_FW_REF} /* ActivityKit.framework */; }};")
W(f"\t\t{WIDGET_EMBED_BF} /* CadenceWidget.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {WIDGET_PRODUCT} /* CadenceWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
# Watch build files
for name, dir in ALL_WATCH:
    phase = "Resources" if (name, dir) in WATCH_RESOURCES else "Sources"
    W(f"\t\t{vfile[key(name,dir)]} /* {name} in {phase} (Watch) */ = {{isa = PBXBuildFile; fileRef = {fref[key(name,dir)]} /* {name} */; }};")
W(f"\t\t{WATCH_EMBED_BF} /* CadenceWatch.app in Embed Watch Content */ = {{isa = PBXBuildFile; fileRef = {WATCH_PRODUCT} /* CadenceWatch.app */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
for name, dir in WATCH_AUDIO_RESOURCES:
    W(f"\t\t{vafile[key(name,dir)]} /* {name} in Resources (Watch Audio) */ = {{isa = PBXBuildFile; fileRef = {fref[key(name,dir)]} /* {name} */; }};")
W("/* End PBXBuildFile section */")
W()

# PBXFileReference
W("/* Begin PBXFileReference section */")
seen_frefs = set()
for name, dir in _all_files_combined:
    k = key(name, dir)
    if k in seen_frefs: continue
    seen_frefs.add(k)
    ft = file_type(name)
    W(f"\t\t{fref[k]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; name = {pbx_val(name)}; path = {pbx_val(name)}; sourceTree = \"<group>\"; }};")
W(f"\t\t{APP_PRODUCT} /* Interval.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Interval.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
W(f"\t\t{WIDGET_PRODUCT} /* CadenceWidget.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = CadenceWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};")
W(f"\t\t{HEALTHKIT_FW_REF} /* HealthKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = HealthKit.framework; path = System/Library/Frameworks/HealthKit.framework; sourceTree = SDKROOT; }};")
W(f"\t\t{ACTIVITYKIT_FW_REF} /* ActivityKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = ActivityKit.framework; path = System/Library/Frameworks/ActivityKit.framework; sourceTree = SDKROOT; }};")
W(f"\t\t{WIDGETKIT_FW_REF} /* WidgetKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; }};")
W(f"\t\t{ENTITLEMENTS_REF} /* Interval.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = \"Interval.entitlements\"; sourceTree = \"<group>\"; }};")
W(f"\t\t{WIDGET_ENTITLEMENTS_REF} /* CadenceWidget.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = \"CadenceWidget.entitlements\"; sourceTree = \"<group>\"; }};")
W(f"\t\t{WATCH_PRODUCT} /* CadenceWatch.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CadenceWatch.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
W(f"\t\t{WATCH_ENTITLEMENTS_REF} /* CadenceWatch.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = \"CadenceWatch.entitlements\"; sourceTree = \"<group>\"; }};")
W(f"\t\t{WATCHCONN_FW_REF} /* WatchConnectivity.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WatchConnectivity.framework; path = System/Library/Frameworks/WatchConnectivity.framework; sourceTree = SDKROOT; }};")
W(f"\t\t{APPINTENTS_FW_REF} /* AppIntents.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = AppIntents.framework; path = System/Library/Frameworks/AppIntents.framework; sourceTree = SDKROOT; }};")
W("/* End PBXFileReference section */")
W()

# PBXFrameworksBuildPhase
W("/* Begin PBXFrameworksBuildPhase section */")
W(f"\t\t{FRAMEWORKS_PHASE} /* Frameworks */ = {{")
W(f"\t\t\tisa = PBXFrameworksBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tfiles = (")
W(f"\t\t\t\t{HEALTHKIT_FW_BF} /* HealthKit.framework in Frameworks */,")
W(f"\t\t\t\t{ACTIVITYKIT_MAIN_BF} /* ActivityKit.framework in Frameworks */,")
W(f"\t\t\t\t{WATCHCONN_FW_BF_IOS} /* WatchConnectivity.framework */,")
W(f"\t\t\t);")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
W(f"\t\t{WIDGET_FRAMEWORKS_PHASE} /* Frameworks (Widget) */ = {{")
W(f"\t\t\tisa = PBXFrameworksBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tfiles = (")
W(f"\t\t\t\t{WIDGETKIT_FW_BF} /* WidgetKit.framework */,")
W(f"\t\t\t\t{ACTIVITYKIT_FW_BF} /* ActivityKit.framework */,")
W(f"\t\t\t\t{APPINTENTS_FW_BF_WIDGET} /* AppIntents.framework */,")
W(f"\t\t\t);")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
W(f"\t\t{WATCH_FRAMEWORKS_PHASE} /* Frameworks (Watch) */ = {{")
W(f"\t\t\tisa = PBXFrameworksBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tfiles = (")
W(f"\t\t\t\t{WATCHCONN_FW_BF_WATCH} /* WatchConnectivity.framework */,")
W(f"\t\t\t);")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
W("/* End PBXFrameworksBuildPhase section */")
W()

# PBXGroup helpers
def files_in(dir_path):
    return [(n, d) for n, d in ALL_FILES if d == dir_path]

def grp(gid, name, children, path=None):
    W(f"\t\t{gid} /* {name} */ = {{")
    W(f"\t\t\tisa = PBXGroup;")
    W(f"\t\t\tchildren = (")
    for cid, cname in children:
        W(f"\t\t\t\t{cid} /* {cname} */,")
    W(f"\t\t\t);")
    if path is not None:
        W(f"\t\t\tpath = {pbx_val(path)};")
    else:
        W(f"\t\t\tname = {pbx_val(name)};")
    W(f"\t\t\tsourceTree = \"<group>\";")
    W(f"\t\t}};")

W("/* Begin PBXGroup section */")

grp(GRP_PRODUCTS, "Products", [(APP_PRODUCT, "Interval.app"), (WIDGET_PRODUCT, "CadenceWidget.appex"), (WATCH_PRODUCT, "CadenceWatch.app")])

soundfx_files = [(fref[key(n,d)], n) for n, d in files_in("Interval/Resources/soundfx")]
grp(GRP_SOUNDFX, "soundfx", soundfx_files, "soundfx")

res_files = [(fref[key(n,d)], n) for n, d in files_in("Interval/Resources")]
grp(GRP_RES, "Resources", res_files + [(GRP_SOUNDFX, "soundfx")], "Resources")

grp(GRP_LIB, "Library",
    [(fref[key(n,d)], n) for n, d in files_in("Interval/Views/Library")], "Library")

grp(GRP_WIZARD, "Wizard",
    [(fref[key(n,d)], n) for n, d in files_in("Interval/Views/Wizard")], "Wizard")

grp(GRP_TIMER, "Timer",
    [(fref[key(n,d)], n) for n, d in files_in("Interval/Views/Timer")], "Timer")

GRP_SETTINGS = uid("GRP_SETTINGS")
grp(GRP_SETTINGS, "Settings",
    [(fref[key(n,d)], n) for n, d in files_in("Interval/Views/Settings")], "Settings")

grp(GRP_VIEWS, "Views",
    [(GRP_LIB, "Library"), (GRP_WIZARD, "Wizard"), (GRP_TIMER, "Timer"), (GRP_SETTINGS, "Settings")], "Views")

grp(GRP_APP, "App",
    [(fref[key(n,d)], n) for n, d in files_in("Interval/App")] +
    [(ENTITLEMENTS_REF, "Interval.entitlements")], "App")

grp(GRP_MODELS, "Models",
    [(fref[key(n,d)], n) for n, d in files_in("Interval/Models")], "Models")

grp(GRP_AUDIO, "Audio",
    [(fref[key(n,d)], n) for n, d in files_in("Interval/Audio")], "Audio")

grp(GRP_UTIL, "Utilities",
    [(fref[key(n,d)], n) for n, d in files_in("Interval/Utilities")], "Utilities")

# "Interval" folder group — wraps all source so paths resolve under Interval/
grp(GRP_INTERVAL, "Interval",
    [(GRP_APP,"App"),(GRP_MODELS,"Models"),(GRP_VIEWS,"Views"),
     (GRP_AUDIO,"Audio"),(GRP_RES,"Resources"),(GRP_UTIL,"Utilities"),
     (HEALTHKIT_FW_REF,"HealthKit.framework")],
    "Interval")

# Widget group — only files that physically live in CadenceWidget/
widget_file_entries = [(fref[key(n,d)], n) for n, d in WIDGET_OWN]
grp(WIDGET_GRP, "CadenceWidget",
    widget_file_entries + [(WIDGET_ENTITLEMENTS_REF, "CadenceWidget.entitlements")],
    "CadenceWidget")

# Watch group — only files that physically live in CadenceWatch/
watch_views_entries = [(fref[key(n,d)], n) for n, d in WATCH_OWN if d == "CadenceWatch/Views"]
grp(WATCH_GRP_VIEWS, "Views", watch_views_entries, "Views")

watch_top_entries = [(fref[key(n,d)], n) for n, d in WATCH_OWN if d == "CadenceWatch"]
watch_res_entries = [(fref[key(n,d)], n) for n, d in WATCH_RESOURCES]
grp(WATCH_GRP, "CadenceWatch",
    watch_top_entries + [(WATCH_GRP_VIEWS, "Views")] + watch_res_entries +
    [(WATCH_ENTITLEMENTS_REF, "CadenceWatch.entitlements")],
    "CadenceWatch")

# Root group (no name/path)
W(f"\t\t{GRP_MAIN} = {{")
W(f"\t\t\tisa = PBXGroup;")
W(f"\t\t\tchildren = (")
for cid, cname in [(GRP_INTERVAL,"Interval"),(WIDGET_GRP,"CadenceWidget"),(WATCH_GRP,"CadenceWatch"),(GRP_PRODUCTS,"Products")]:
    W(f"\t\t\t\t{cid} /* {cname} */,")
W(f"\t\t\t);")
W(f"\t\t\tsourceTree = \"<group>\";")
W(f"\t\t}};")

W("/* End PBXGroup section */")
W()

# PBXNativeTarget
W("/* Begin PBXNativeTarget section */")
W(f"\t\t{TARGET_ID} /* Interval */ = {{")
W(f"\t\t\tisa = PBXNativeTarget;")
W(f"\t\t\tbuildConfigurationList = {TGT_CFG_LIST} /* Build configuration list for PBXNativeTarget \"Interval\" */;")
W(f"\t\t\tbuildPhases = (")
W(f"\t\t\t\t{SOURCES_PHASE} /* Sources */,")
W(f"\t\t\t\t{FRAMEWORKS_PHASE} /* Frameworks */,")
W(f"\t\t\t\t{RESOURCES_PHASE} /* Resources */,")
W(f"\t\t\t\t{WIDGET_EMBED_PHASE} /* Embed App Extensions */,")
W(f"\t\t\t\t{WATCH_EMBED_PHASE} /* Embed Watch Content */,")
W(f"\t\t\t);")
W(f"\t\t\tbuildRules = (")
W(f"\t\t\t);")
W(f"\t\t\tdependencies = (")
W(f"\t\t\t\t{WIDGET_DEPENDENCY_ID} /* PBXTargetDependency */,")
W(f"\t\t\t\t{WATCH_DEPENDENCY_ID} /* PBXTargetDependency (Watch) */,")
W(f"\t\t\t);")
W(f"\t\t\tname = Interval;")
W(f"\t\t\tproductName = Interval;")
W(f"\t\t\tproductReference = {APP_PRODUCT} /* Interval.app */;")
W(f"\t\t\tproductType = \"com.apple.product-type.application\";")
W(f"\t\t}};")
W(f"\t\t{WIDGET_TARGET_ID} /* CadenceWidget */ = {{")
W(f"\t\t\tisa = PBXNativeTarget;")
W(f"\t\t\tbuildConfigurationList = {WIDGET_CFG_LIST} /* Build configuration list for PBXNativeTarget \"CadenceWidget\" */;")
W(f"\t\t\tbuildPhases = (")
W(f"\t\t\t\t{WIDGET_SOURCES_PHASE} /* Sources */,")
W(f"\t\t\t\t{WIDGET_FRAMEWORKS_PHASE} /* Frameworks */,")
W(f"\t\t\t\t{WIDGET_RESOURCES_PHASE} /* Resources */,")
W(f"\t\t\t);")
W(f"\t\t\tbuildRules = (")
W(f"\t\t\t);")
W(f"\t\t\tdependencies = (")
W(f"\t\t\t);")
W(f"\t\t\tname = CadenceWidget;")
W(f"\t\t\tproductName = CadenceWidget;")
W(f"\t\t\tproductReference = {WIDGET_PRODUCT} /* CadenceWidget.appex */;")
W(f"\t\t\tproductType = \"com.apple.product-type.app-extension\";")
W(f"\t\t}};")
W(f"\t\t{WATCH_TARGET_ID} /* CadenceWatch */ = {{")
W(f"\t\t\tisa = PBXNativeTarget;")
W(f"\t\t\tbuildConfigurationList = {WATCH_CFG_LIST} /* Build configuration list for PBXNativeTarget \"CadenceWatch\" */;")
W(f"\t\t\tbuildPhases = (")
W(f"\t\t\t\t{WATCH_SOURCES_PHASE} /* Sources */,")
W(f"\t\t\t\t{WATCH_FRAMEWORKS_PHASE} /* Frameworks */,")
W(f"\t\t\t\t{WATCH_RESOURCES_PHASE} /* Resources */,")
W(f"\t\t\t);")
W(f"\t\t\tbuildRules = (")
W(f"\t\t\t);")
W(f"\t\t\tdependencies = (")
W(f"\t\t\t);")
W(f"\t\t\tname = CadenceWatch;")
W(f"\t\t\tproductName = CadenceWatch;")
W(f"\t\t\tproductReference = {WATCH_PRODUCT} /* CadenceWatch.app */;")
W(f"\t\t\tproductType = \"com.apple.product-type.application\";")
W(f"\t\t}};")
W("/* End PBXNativeTarget section */")
W()

# PBXProject
W("/* Begin PBXProject section */")
W(f"\t\t{PROJECT_ID} /* Project object */ = {{")
W(f"\t\t\tisa = PBXProject;")
W(f"\t\t\tattributes = {{")
W(f"\t\t\t\tBuildIndependentTargetsInParallel = 1;")
W(f"\t\t\t\tLastUpgradeCheck = 1700;")
W(f"\t\t\t\tTargetAttributes = {{")
W(f"\t\t\t\t\t{TARGET_ID} = {{")
W(f"\t\t\t\t\t\tCreatedOnToolsVersion = 17.0;")
W(f"\t\t\t\t\t}};")
W(f"\t\t\t\t\t{WIDGET_TARGET_ID} = {{")
W(f"\t\t\t\t\t\tCreatedOnToolsVersion = 17.0;")
W(f"\t\t\t\t\t}};")
W(f"\t\t\t\t\t{WATCH_TARGET_ID} = {{")
W(f"\t\t\t\t\t\tCreatedOnToolsVersion = 17.0;")
W(f"\t\t\t\t\t}};")
W(f"\t\t\t\t}};")
W(f"\t\t\t}};")
W(f"\t\t\tbuildConfigurationList = {PROJ_CFG_LIST} /* Build configuration list for PBXProject \"Interval\" */;")
W(f"\t\t\tdevelopmentRegion = en;")
W(f"\t\t\thasScannedForEncodings = 0;")
W(f"\t\t\tknownRegions = (")
W(f"\t\t\t\ten,")
W(f"\t\t\t\tBase,")
W(f"\t\t\t);")
W(f"\t\t\tmainGroup = {GRP_MAIN};")
W(f"\t\t\tminimizedProjectReferenceProxies = 1;")
W(f"\t\t\tpreferredProjectObjectVersion = 77;")
W(f"\t\t\tproductRefGroup = {GRP_PRODUCTS} /* Products */;")
W(f"\t\t\tprojectDirPath = \"\";")
W(f"\t\t\tprojectRoot = \"\";")
W(f"\t\t\ttargets = (")
W(f"\t\t\t\t{TARGET_ID} /* Interval */,")
W(f"\t\t\t\t{WIDGET_TARGET_ID} /* CadenceWidget */,")
W(f"\t\t\t\t{WATCH_TARGET_ID} /* CadenceWatch */,")
W(f"\t\t\t);")
W(f"\t\t}};")
W("/* End PBXProject section */")
W()

# PBXResourcesBuildPhase
W("/* Begin PBXResourcesBuildPhase section */")
W(f"\t\t{RESOURCES_PHASE} /* Resources */ = {{")
W(f"\t\t\tisa = PBXResourcesBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tfiles = (")
for name, dir in RESOURCES:
    W(f"\t\t\t\t{bfile[key(name,dir)]} /* {name} in Resources */,")
W(f"\t\t\t);")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
W(f"\t\t{WIDGET_EMBED_PHASE} /* Embed App Extensions */ = {{")
W(f"\t\t\tisa = PBXCopyFilesBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tdstPath = \"\";")
W(f"\t\t\tdstSubfolderSpec = 13;")
W(f"\t\t\tfiles = (")
W(f"\t\t\t\t{WIDGET_EMBED_BF} /* CadenceWidget.appex in Embed App Extensions */,")
W(f"\t\t\t);")
W(f"\t\t\tname = \"Embed App Extensions\";")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
W(f"\t\t{WIDGET_RESOURCES_PHASE} /* Resources (Widget) */ = {{")
W(f"\t\t\tisa = PBXResourcesBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tfiles = (")
W(f"\t\t\t);")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
# Watch embed in iOS app
W(f"\t\t{WATCH_EMBED_PHASE} /* Embed Watch Content */ = {{")
W(f"\t\t\tisa = PBXCopyFilesBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tdstPath = \"$(CONTENTS_FOLDER_PATH)/Watch\";")
W(f"\t\t\tdstSubfolderSpec = 16;")
W(f"\t\t\tfiles = (")
W(f"\t\t\t\t{WATCH_EMBED_BF} /* CadenceWatch.app in Embed Watch Content */,")
W(f"\t\t\t);")
W(f"\t\t\tname = \"Embed Watch Content\";")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
# Watch resources phase
W(f"\t\t{WATCH_RESOURCES_PHASE} /* Resources (Watch) */ = {{")
W(f"\t\t\tisa = PBXResourcesBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tfiles = (")
for name, dir in WATCH_RESOURCES:
    W(f"\t\t\t\t{vfile[key(name,dir)]} /* {name} in Resources (Watch) */,")
for name, dir in WATCH_AUDIO_RESOURCES:
    W(f"\t\t\t\t{vafile[key(name,dir)]} /* {name} in Resources (Watch Audio) */,")
W(f"\t\t\t);")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
W("/* End PBXResourcesBuildPhase section */")
W()

# PBXSourcesBuildPhase
W("/* Begin PBXSourcesBuildPhase section */")
W(f"\t\t{SOURCES_PHASE} /* Sources */ = {{")
W(f"\t\t\tisa = PBXSourcesBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tfiles = (")
for name, dir in SOURCES:
    W(f"\t\t\t\t{bfile[key(name,dir)]} /* {name} in Sources */,")
W(f"\t\t\t);")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
W(f"\t\t{WIDGET_SOURCES_PHASE} /* Sources (Widget) */ = {{")
W(f"\t\t\tisa = PBXSourcesBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tfiles = (")
for name, dir in ALL_WIDGET:
    W(f"\t\t\t\t{wfile[key(name,dir)]} /* {name} in Sources (Widget) */,")
W(f"\t\t\t);")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
W(f"\t\t{WATCH_SOURCES_PHASE} /* Sources (Watch) */ = {{")
W(f"\t\t\tisa = PBXSourcesBuildPhase;")
W(f"\t\t\tbuildActionMask = 2147483647;")
W(f"\t\t\tfiles = (")
for name, dir in WATCH_SOURCES:
    W(f"\t\t\t\t{vfile[key(name,dir)]} /* {name} in Sources (Watch) */,")
W(f"\t\t\t);")
W(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
W(f"\t\t}};")
W("/* End PBXSourcesBuildPhase section */")
W()

# PBXContainerItemProxy  (must come before PBXTargetDependency which refs it)
W("/* Begin PBXContainerItemProxy section */")
W(f"\t\t{WIDGET_PROXY_ID} /* PBXContainerItemProxy */ = {{")
W(f"\t\t\tisa = PBXContainerItemProxy;")
W(f"\t\t\tcontainerPortal = {PROJECT_ID} /* Project object */;")
W(f"\t\t\tproxyType = 1;")
W(f"\t\t\tremoteGlobalIDString = {WIDGET_TARGET_ID};")
W(f"\t\t\tremoteInfo = CadenceWidget;")
W(f"\t\t}};")
W(f"\t\t{WATCH_PROXY_ID} /* PBXContainerItemProxy (Watch) */ = {{")
W(f"\t\t\tisa = PBXContainerItemProxy;")
W(f"\t\t\tcontainerPortal = {PROJECT_ID} /* Project object */;")
W(f"\t\t\tproxyType = 1;")
W(f"\t\t\tremoteGlobalIDString = {WATCH_TARGET_ID};")
W(f"\t\t\tremoteInfo = CadenceWatch;")
W(f"\t\t}};")
W("/* End PBXContainerItemProxy section */")
W()

# PBXTargetDependency
W("/* Begin PBXTargetDependency section */")
W(f"\t\t{WIDGET_DEPENDENCY_ID} /* PBXTargetDependency */ = {{")
W(f"\t\t\tisa = PBXTargetDependency;")
W(f"\t\t\ttarget = {WIDGET_TARGET_ID} /* CadenceWidget */;")
W(f"\t\t\ttargetProxy = {WIDGET_PROXY_ID} /* PBXContainerItemProxy */;")
W(f"\t\t}};")
W(f"\t\t{WATCH_DEPENDENCY_ID} /* PBXTargetDependency (Watch) */ = {{")
W(f"\t\t\tisa = PBXTargetDependency;")
W(f"\t\t\ttarget = {WATCH_TARGET_ID} /* CadenceWatch */;")
W(f"\t\t\ttargetProxy = {WATCH_PROXY_ID} /* PBXContainerItemProxy */;")
W(f"\t\t}};")
W("/* End PBXTargetDependency section */")
W()

# XCBuildConfiguration — keep settings minimal and known-good
def cfg(cid, name, settings):
    W(f"\t\t{cid} /* {name} */ = {{")
    W(f"\t\t\tisa = XCBuildConfiguration;")
    W(f"\t\t\tbuildSettings = {{")
    for k in sorted(settings):
        W(f"\t\t\t\t{k} = {settings[k]};")
    W(f"\t\t\t}};")
    W(f"\t\t\tname = {name};")
    W(f"\t\t}};")

base = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "MTL_FAST_MATH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "6.0",
}

proj_debug = dict(base, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
})

proj_release = dict(base, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ONLY_ACTIVE_ARCH": "NO",
    "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
    "VALIDATE_PRODUCT": "YES",
})

tgt_common = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_ENTITLEMENTS": '"Interval/Interval.entitlements"',
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "PY37T7BRM9",
    "CURRENT_PROJECT_VERSION": "1",
    # Use a hand-crafted Info.plist so UIBackgroundModes is a proper array
    # (GENERATE_INFOPLIST_FILE cannot produce array values for UIBackgroundModes)
    "INFOPLIST_FILE": '"Interval/Info.plist"',
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.christiankasper.cadence",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "6.0",
    "TARGETED_DEVICE_FAMILY": '"1"',
}

widget_common = {
    "CODE_SIGN_ENTITLEMENTS": '"CadenceWidget/CadenceWidget.entitlements"',
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "PY37T7BRM9",
    "CURRENT_PROJECT_VERSION": "1",
    "INFOPLIST_FILE": '"CadenceWidget/Info.plist"',
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"',
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.christiankasper.cadence.widget",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SKIP_INSTALL": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "6.0",
    "TARGETED_DEVICE_FAMILY": '"1"',
}

watch_common = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "CODE_SIGN_ENTITLEMENTS": '"CadenceWatch/CadenceWatch.entitlements"',
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "PY37T7BRM9",
    "CURRENT_PROJECT_VERSION": "1",
    "INFOPLIST_FILE": '"CadenceWatch/Info.plist"',
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.christiankasper.cadence.watchkitapp",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SDKROOT": "watchos",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "6.0",
    "TARGETED_DEVICE_FAMILY": '"4"',
    "WATCHOS_DEPLOYMENT_TARGET": "10.0",
}

W("/* Begin XCBuildConfiguration section */")
cfg(PROJ_DEBUG,    "Debug",   proj_debug)
cfg(PROJ_RELEASE,  "Release", proj_release)
cfg(TGT_DEBUG,     "Debug",   tgt_common)
cfg(TGT_RELEASE,   "Release", tgt_common)
cfg(WIDGET_DEBUG,  "Debug",   widget_common)
cfg(WIDGET_RELEASE,"Release", widget_common)
cfg(WATCH_DEBUG,   "Debug",   watch_common)
cfg(WATCH_RELEASE, "Release", watch_common)
W("/* End XCBuildConfiguration section */")
W()

# XCConfigurationList
W("/* Begin XCConfigurationList section */")
W(f"\t\t{PROJ_CFG_LIST} /* Build configuration list for PBXProject \"Interval\" */ = {{")
W(f"\t\t\tisa = XCConfigurationList;")
W(f"\t\t\tbuildConfigurations = (")
W(f"\t\t\t\t{PROJ_DEBUG} /* Debug */,")
W(f"\t\t\t\t{PROJ_RELEASE} /* Release */,")
W(f"\t\t\t);")
W(f"\t\t\tdefaultConfigurationIsVisible = 0;")
W(f"\t\t\tdefaultConfigurationName = Release;")
W(f"\t\t}};")

W(f"\t\t{TGT_CFG_LIST} /* Build configuration list for PBXNativeTarget \"Interval\" */ = {{")
W(f"\t\t\tisa = XCConfigurationList;")
W(f"\t\t\tbuildConfigurations = (")
W(f"\t\t\t\t{TGT_DEBUG} /* Debug */,")
W(f"\t\t\t\t{TGT_RELEASE} /* Release */,")
W(f"\t\t\t);")
W(f"\t\t\tdefaultConfigurationIsVisible = 0;")
W(f"\t\t\tdefaultConfigurationName = Release;")
W(f"\t\t}};")

W(f"\t\t{WIDGET_CFG_LIST} /* Build configuration list for PBXNativeTarget \"CadenceWidget\" */ = {{")
W(f"\t\t\tisa = XCConfigurationList;")
W(f"\t\t\tbuildConfigurations = (")
W(f"\t\t\t\t{WIDGET_DEBUG} /* Debug */,")
W(f"\t\t\t\t{WIDGET_RELEASE} /* Release */,")
W(f"\t\t\t);")
W(f"\t\t\tdefaultConfigurationIsVisible = 0;")
W(f"\t\t\tdefaultConfigurationName = Release;")
W(f"\t\t}};")

W(f"\t\t{WATCH_CFG_LIST} /* Build configuration list for PBXNativeTarget \"CadenceWatch\" */ = {{")
W(f"\t\t\tisa = XCConfigurationList;")
W(f"\t\t\tbuildConfigurations = (")
W(f"\t\t\t\t{WATCH_DEBUG} /* Debug */,")
W(f"\t\t\t\t{WATCH_RELEASE} /* Release */,")
W(f"\t\t\t);")
W(f"\t\t\tdefaultConfigurationIsVisible = 0;")
W(f"\t\t\tdefaultConfigurationName = Release;")
W(f"\t\t}};")
W("/* End XCConfigurationList section */")
W()

W("\t};")
W(f"\trootObject = {PROJECT_ID} /* Project object */;")
W("}")

# Write
pbxproj = os.path.join(PROJ_DIR, "project.pbxproj")
with open(pbxproj, "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print(f"✓ {pbxproj}")
print(f"  {len(SOURCES)} source files | {len(RESOURCES)} resource files")
