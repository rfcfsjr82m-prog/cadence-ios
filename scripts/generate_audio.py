#!/usr/bin/env python3
"""
generate_audio.py — Cadence prayer pipeline: TTS Text (sheet col AB) -> MP3s.

Turns each prayer's ElevenLabs breath-form text into two audio files named to
match the app's GitHub audio convention:

    {ID}_m.mp3   (male voice)
    {ID}_f.mp3   (female voice)

No third-party dependencies — standard library only. Run:

    python3 scripts/generate_audio.py --csv export.csv
    python3 scripts/generate_audio.py --csv export.csv --ids 217,218 --force
    python3 scripts/generate_audio.py --id 217 --text-file prayer.txt --voice female

Input is normally a CSV export of the prayers tab
(File -> Download -> Comma-separated values in Google Sheets). The script reads
the ID from column B and the TTS text from column AB.

The API key is read from scripts/secrets.local.json (gitignored) or the
ELEVENLABS_API_KEY environment variable.
"""

import argparse
import csv
import json
import os
import sys
import urllib.error
import urllib.request

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

MODEL_ID = "eleven_multilingual_v2"

VOICES = {
    "male":   "2OcnG4mH3jIMtWz3vKus",
    "female": "flHkNRp1BlvT73UL6gyz",
}

# Filename suffix per voice (matches app convention {ID}_m / {ID}_f).
SUFFIX = {"male": "m", "female": "f"}

# mp3, 44.1 kHz, 128 kbps — good quality, reasonable size.
OUTPUT_FORMAT = "mp3_44100_128"

# Tuned for a calm, steady prayer reading. Edit to taste.
# "speed": ElevenLabs playback speed, range 0.7-1.2 (1.0 = normal). Prayers read
# best a little slower and meditative, so we default below 1.0. Override per run
# with --speed.
DEFAULT_SPEED = 0.9

# "stability": ElevenLabs voice stability, range 0.0-1.0. LOWER = more expressive
# and dramatic (can sound commanding/preachy); HIGHER = calmer, steadier, more
# even. 0.7-0.75 reads best for meditative prayer. Override per run with
# --stability.
DEFAULT_STABILITY = 0.72

VOICE_SETTINGS = {
    "stability":        DEFAULT_STABILITY,
    "similarity_boost": 0.75,
    "style":            0.0,
    "use_speaker_boost": True,
    "speed":            DEFAULT_SPEED,
}

# Sheet columns (1-based, to match the spreadsheet). B = id, AB = TTS text.
ID_COL_DEFAULT  = 2
TTS_COL_DEFAULT = 28

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT_DIR = os.path.join(SCRIPT_DIR, "audio_out")
SECRETS_PATH = os.path.join(SCRIPT_DIR, "secrets.local.json")

API_BASE = "https://api.elevenlabs.io/v1/text-to-speech"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_api_key():
    if os.environ.get("ELEVENLABS_API_KEY"):
        return os.environ["ELEVENLABS_API_KEY"].strip()
    if os.path.exists(SECRETS_PATH):
        with open(SECRETS_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        key = data.get("ELEVENLABS_API_KEY", "").strip()
        if key:
            return key
    sys.exit(
        "No API key found. Set ELEVENLABS_API_KEY or add it to "
        + SECRETS_PATH
    )


def synthesize(api_key, voice_id, text, speed=DEFAULT_SPEED, stability=DEFAULT_STABILITY):
    """Call ElevenLabs and return raw MP3 bytes (raises on HTTP error)."""
    url = "%s/%s?output_format=%s" % (API_BASE, voice_id, OUTPUT_FORMAT)
    settings = dict(VOICE_SETTINGS)
    settings["speed"] = speed
    settings["stability"] = stability
    body = json.dumps({
        "text": text,
        "model_id": MODEL_ID,
        "voice_settings": settings,
    }).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("xi-api-key", api_key)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "audio/mpeg")
    with urllib.request.urlopen(req) as resp:
        return resp.read()


def expand_ids(spec):
    """Parse an --ids spec into a set of id strings.

    Accepts comma-separated ids and numeric ranges, e.g.
    "106-110"        -> {106,107,108,109,110}
    "106-108,219"    -> {106,107,108,219}
    Non-numeric ids (e.g. "ps23") are kept as-is.
    """
    out = set()
    for token in spec.split(","):
        token = token.strip()
        if not token:
            continue
        if "-" in token:
            lo, hi = token.split("-", 1)
            lo, hi = lo.strip(), hi.strip()
            if lo.isdigit() and hi.isdigit():
                for n in range(int(lo), int(hi) + 1):
                    out.add(str(n))
                continue
        out.add(token)
    return out


def read_rows_from_csv(path, id_col, tts_col):
    """Yield (id, tts_text) for rows that have both an id and TTS text."""
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        for cells in reader:
            if len(cells) < max(id_col, tts_col):
                continue
            raw_id = cells[id_col - 1].strip()
            tts = cells[tts_col - 1].strip()
            if not raw_id or not tts:
                continue
            # Skip a header row (id column not numeric).
            if not raw_id.replace(".", "", 1).isdigit():
                continue
            yield raw_id, tts


def generate_one(api_key, out_dir, prayer_id, text, voices, force, speed=DEFAULT_SPEED, stability=DEFAULT_STABILITY):
    made = []
    for voice in voices:
        suffix = SUFFIX[voice]
        out_path = os.path.join(out_dir, "%s_%s.mp3" % (prayer_id, suffix))
        if os.path.exists(out_path) and not force:
            print("  skip  %s (exists; use --force to overwrite)"
                  % os.path.basename(out_path))
            continue
        try:
            audio = synthesize(api_key, VOICES[voice], text, speed, stability)
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")
            print("  ERROR %s_%s: HTTP %s %s"
                  % (prayer_id, suffix, e.code, detail))
            continue
        except urllib.error.URLError as e:
            print("  ERROR %s_%s: %s" % (prayer_id, suffix, e.reason))
            continue
        with open(out_path, "wb") as f:
            f.write(audio)
        kb = len(audio) / 1024.0
        print("  wrote %s (%.0f KB)" % (os.path.basename(out_path), kb))
        made.append(out_path)
    return made


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(description="Generate ElevenLabs MP3s for prayers.")
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--csv", help="CSV export of the prayers tab.")
    src.add_argument("--id", help="Single prayer id (use with --text/--text-file).")
    p.add_argument("--text", help="TTS text for single-prayer mode.")
    p.add_argument("--text-file", help="File containing TTS text for single mode.")
    p.add_argument("--ids", help="Ids to include (CSV mode). Comma list and/or ranges, e.g. 106-110,219.")
    p.add_argument("--voice", choices=["male", "female", "both"], default="both")
    p.add_argument("--out", default=DEFAULT_OUT_DIR, help="Output directory.")
    p.add_argument("--force", action="store_true", help="Overwrite existing files.")
    p.add_argument("--id-col", type=int, default=ID_COL_DEFAULT,
                   help="1-based id column in the CSV (default 2 = B).")
    p.add_argument("--tts-col", type=int, default=TTS_COL_DEFAULT,
                   help="1-based TTS column in the CSV (default 28 = AB).")
    p.add_argument("--speed", type=float, default=DEFAULT_SPEED,
                   help="Reading speed 0.7-1.2 (1.0 = normal, lower = slower). "
                        "Default %.2f." % DEFAULT_SPEED)
    p.add_argument("--stability", type=float, default=DEFAULT_STABILITY,
                   help="Voice stability 0.0-1.0 (higher = calmer/steadier, "
                        "lower = more expressive/commanding). Default %.2f."
                        % DEFAULT_STABILITY)
    args = p.parse_args()

    if not (0.7 <= args.speed <= 1.2):
        sys.exit("--speed must be between 0.7 and 1.2 (ElevenLabs range).")
    if not (0.0 <= args.stability <= 1.0):
        sys.exit("--stability must be between 0.0 and 1.0.")

    voices = ["male", "female"] if args.voice == "both" else [args.voice]
    api_key = load_api_key()
    os.makedirs(args.out, exist_ok=True)

    # Single-prayer mode --------------------------------------------------
    if args.id:
        if args.text_file:
            with open(args.text_file, "r", encoding="utf-8") as f:
                text = f.read().strip()
        elif args.text:
            text = args.text.strip()
        else:
            sys.exit("Single mode needs --text or --text-file.")
        print("Prayer %s:" % args.id)
        generate_one(api_key, args.out, args.id, text, voices, args.force, args.speed, args.stability)
        return

    # CSV batch mode ------------------------------------------------------
    wanted = None
    if args.ids:
        wanted = expand_ids(args.ids)

    rows = list(read_rows_from_csv(args.csv, args.id_col, args.tts_col))
    if wanted is not None:
        rows = [r for r in rows if r[0] in wanted]
        missing = wanted - {r[0] for r in rows}
        if missing:
            print("Note: no TTS text found for ids: %s" % ", ".join(sorted(missing)))

    if not rows:
        sys.exit("No rows with TTS text found. Check --id-col/--tts-col.")

    print("Generating %d prayer(s) x %d voice(s) at speed %.2f, stability %.2f -> %s\n"
          % (len(rows), len(voices), args.speed, args.stability, args.out))
    total = 0
    for prayer_id, text in rows:
        print("Prayer %s:" % prayer_id)
        total += len(generate_one(api_key, args.out, prayer_id, text, voices, args.force, args.speed, args.stability))
    print("\nDone. %d file(s) written to %s" % (total, args.out))


if __name__ == "__main__":
    main()
