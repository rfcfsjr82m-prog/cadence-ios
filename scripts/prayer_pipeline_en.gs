/**
 * Cadence — Prayer Pipeline (Google Apps Script) — ENGLISH EDITION
 * =================================================
 * Bound to the ENGLISH prayer-collection Google Sheet.
 * Differs from the German script only in: COL_ID (A), COL_PRAYER_TEXT (B),
 * English-language generation prompts, and no ID skip range in the Style step.
 *
 * Function 1 of the pipeline: VERSE / TTS FORMATTER
 * Reads the raw "Prayer Text" (col C) and writes:
 *   - col AB ("TTS Text")     : clause-level lines + a <break time="0.5s" /> between the
 *                               prayer's major sections only (a handful — ElevenLabs cuts
 *                               out if a generation has many break tags)
 *   - col AC ("JSON Format")  : same clause-level lines, blank line between paragraphs, no breaks
 *
 * The LLM (Gemini) does ONLY the hard part: splitting the prose into paragraphs
 * of natural clause-level lines. This script formats both outputs deterministically
 * from that single result, so TTS and JSON always stay in sync.
 *
 * SETUP (one time):
 *   1. In the sheet: Extensions → Apps Script. Paste this whole file. Save.
 *   2. Project Settings → Script Properties → add property:
 *        GEMINI_API_KEY = <your key from https://aistudio.google.com/apikey>
 *   3. Reload the sheet. A "Prayer Tools" menu appears.
 *
 * USAGE:
 *   - Select one or more rows in the sheet (click the row numbers).
 *   - Prayer Tools → Generate TTS + JSON (selected rows)
 *   OR
 *   - Prayer Tools → Generate TTS + JSON (rows missing it)  ← scans all rows,
 *     fills only where C has text and AB/AC are still empty.
 */

// ---------------------------------------------------------------------------
// CONFIG
// ---------------------------------------------------------------------------
var CONFIG = {
  COL_ID:          1,    // A  — prayer id (the 501… numbers; col A "ID")
  COL_PRAYER_TEXT: 2,    // B  — raw input (col B "Eng Prayer Text")
  COL_TITLE:       4,    // D  — title (in/out)
  COL_DESCRIPTION: 5,    // E  — short description (in/out)
  COL_AUTHOR:      6,    // F  — author (context)
  COL_ADDITION:    7,    // G  — life dates / addition (context)
  COL_SOURCE:      8,    // H  — source (context)
  COL_TONALITY:    18,   // R  — Tonalität (in/out): Zeitlos|Klassisch|Historisch|Zeitgemäß
  COL_PRAYER_STONE: 19,  // S  — Suited for Prayer Stone (in/out): Yes|No|Maybe
  COL_KW_FIRST:    20,   // T  — Keyword 1  (keywords span T..X)
  COL_KW_LAST:     24,   // X  — Keyword 5
  COL_CAT_FIRST:   25,   // Y  — Sammlung I  (categories span Y..AA)
  COL_CAT_LAST:    27,   // AA — Sammlung III

  // Keywords are read LIVE from a tab so they always match what you curate.
  KEYWORDS_TAB:        'Keywords',  // tab name (matched case-insensitively)
  KEYWORDS_COL:        2,           // column holding the English keyword list (B). A "Keyword" header row is auto-skipped.
  MAX_KEYWORDS:        5,
  MAX_CATEGORIES:      3,

  // Categories are read LIVE from a tab (English edition), just like keywords,
  // so they always match what you curate — no hardcoded list to keep in sync.
  CATEGORIES_TAB:      'Categories',  // tab name (matched case-insensitively)
  CATEGORIES_COL:      2,             // column holding the English category list (B). A "Category" header row is auto-skipped.

  // Categories the AI classifier must NEVER pick — "Rosary" and "Prayer Patterns"
  // (Gebetsmuster) describe a manual grouping the model can't judge, so they are
  // attributed by hand. They stay valid values for manual entry and Build JSON;
  // only the AI is barred from choosing them. Matched case-insensitively.
  CATEGORIES_AI_EXCLUDE: ['Rosary', 'Prayer Patterns'],

  // Style hard-rule: any prayer whose categories include THIS category name is
  // tagged Classic without a model call (the English equivalent of "Klassiker").
  // Set this to your English classic-collection category exactly as it appears in
  // the Categories tab. Leave '' to disable the hard-rule (model decides every row).
  STYLE_CLASSIC_CATEGORY: '',
  COL_TTS_TEXT:    28,   // AB — output: ElevenLabs TTS
  COL_JSON_FORMAT: 29,   // AC — output: verse text for JSON (\n line breaks)
  COL_JSON_OUTPUT: 30,   // AD — output: full per-prayer JSON object
  COL_STYLE:       31,   // AE — style tag: Modern | Poetic | Classic
  HEADER_ROWS:     1,    // number of header rows at the top of the sheet
  BREAK_TAG:       '<break time="0.5s" />',
  GEMINI_MODEL:    'gemini-2.5-flash',  // cheap & fast; good clause-level chunking.
                                        // Use 'gemini-2.5-pro' if you want tighter line breaks.
};

// ---------------------------------------------------------------------------
// MENU
// ---------------------------------------------------------------------------
function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Prayer Tools')
    .addItem('Generate TTS + JSON (selected rows)', 'runForSelectedRows')
    .addItem('Generate TTS + JSON (rows missing it)', 'runForMissingRows')
    .addSeparator()
    .addItem('Generate Title + Description (selected rows)', 'runTitleDescForSelectedRows')
    .addItem('Generate Title + Description (rows missing it)', 'runTitleDescForMissingRows')
    .addSeparator()
    .addItem('Generate Tonalität + Prayer Stone (selected rows)', 'runTonalityForSelectedRows')
    .addItem('Generate Tonalität + Prayer Stone (rows missing it)', 'runTonalityForMissingRows')
    .addSeparator()
    .addItem('Generate Categories + Keywords (selected rows)', 'runCatKwForSelectedRows')
    .addItem('Generate Categories + Keywords (rows missing it)', 'runCatKwForMissingRows')
    .addSeparator()
    .addItem('Generate Style (selected rows)', 'runStyleForSelectedRows')
    .addItem('Generate Style (rows missing it)', 'runStyleForMissingRows')
    .addSeparator()
    .addItem('Build JSON (selected rows)', 'runBuildJsonForSelectedRows')
    .addSeparator()
    .addItem('Debug: keyword list', 'debugKeywords')
    .addItem('Debug: category list', 'debugCategories')
    .addToUi();
}

// ---------------------------------------------------------------------------
// ROW SELECTION — "tell which rows need this"
// ---------------------------------------------------------------------------

/** Runs on whatever rows you have selected in the sheet. */
function runForSelectedRows() {
  var sheet = SpreadsheetApp.getActiveSheet();
  var ranges = sheet.getActiveRangeList().getRanges();
  var rows = {};
  ranges.forEach(function (r) {
    for (var i = 0; i < r.getNumRows(); i++) {
      var row = r.getRow() + i;
      if (row > CONFIG.HEADER_ROWS) rows[row] = true;
    }
  });
  runForRows(Object.keys(rows).map(Number).sort(function (a, b) { return a - b; }));
}

/** Runs on every data row where C has text but AB or AC is empty. */
function runForMissingRows() {
  var sheet = SpreadsheetApp.getActiveSheet();
  var lastRow = sheet.getLastRow();
  var rows = [];
  for (var row = CONFIG.HEADER_ROWS + 1; row <= lastRow; row++) {
    var raw = sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue();
    var tts = sheet.getRange(row, CONFIG.COL_TTS_TEXT).getValue();
    var json = sheet.getRange(row, CONFIG.COL_JSON_FORMAT).getValue();
    if (String(raw).trim() && (!String(tts).trim() || !String(json).trim())) {
      rows.push(row);
    }
  }
  runForRows(rows);
}

/**
 * Core entry point. Pass an explicit array of sheet row numbers, e.g.
 * from the Apps Script editor:  runForRows([2, 5, 6]);
 */
function runForRows(rowNumbers) {
  if (!rowNumbers || !rowNumbers.length) {
    SpreadsheetApp.getActive().toast('No matching rows.', 'Prayer Tools', 5);
    return;
  }
  var sheet = SpreadsheetApp.getActiveSheet();
  var ok = 0, fail = 0, errors = [];

  rowNumbers.forEach(function (row) {
    var raw = String(sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue()).trim();
    if (!raw) { return; }
    try {
      var paragraphs = chunkPrayerWithGemini(raw);
      sheet.getRange(row, CONFIG.COL_TTS_TEXT).setValue(buildTtsText(paragraphs));
      sheet.getRange(row, CONFIG.COL_JSON_FORMAT).setValue(buildJsonText(paragraphs));
      SpreadsheetApp.flush();
      ok++;
    } catch (e) {
      fail++;
      errors.push('Row ' + row + ': ' + e.message);
    }
  });

  var msg = ok + ' done' + (fail ? ', ' + fail + ' failed' : '');
  if (errors.length) {
    Logger.log(errors.join('\n'));
    msg += '\n' + errors[0];   // surface the first failure so it isn't silently hidden
  }
  SpreadsheetApp.getActive().toast(msg, 'Prayer Tools', 12);
}

// ---------------------------------------------------------------------------
// FORMATTING — deterministic, from the LLM's paragraph structure
// ---------------------------------------------------------------------------

/**
 * paragraphs: Array<Array<string>>  (paragraph → clause-level lines) — for TTS.
 * Clause lines sit on their own lines so the natural punctuation (commas, semicolons,
 * periods) and line breaks create the reading pauses. A <break> tag is inserted ONLY
 * between paragraphs (the prayer's major sections) — never between every line.
 * ElevenLabs destabilises and cuts out when a single generation has many break tags,
 * so we use just a handful (one per section boundary, none after the closing line).
 */
function buildTtsText(paragraphs) {
  var blocks = paragraphs.map(function (lines) { return lines.join('\n'); });
  return blocks.join('\n' + CONFIG.BREAK_TAG + '\n');
}

/**
 * paragraphs: Array<Array<string>>  (paragraph → clause-level lines) — on-screen reading.
 * Same line structure as the TTS text, but blank lines between paragraphs instead of
 * break tags (no <break> markup in the displayed text).
 */
function buildJsonText(paragraphs) {
  return paragraphs.map(function (lines) { return lines.join('\n'); }).join('\n\n');
}

// ---------------------------------------------------------------------------
// LLM — Gemini does the semantic chunking only
// ---------------------------------------------------------------------------

function getApiKey_() {
  var key = PropertiesService.getScriptProperties().getProperty('GEMINI_API_KEY');
  if (!key) throw new Error('Set GEMINI_API_KEY in Script Properties.');
  return key;
}

function chunkPrayerWithGemini(rawText) {
  var correction = '';
  var lastDiff = '';
  // Up to 3 rounds. If the model drops or adds words (guided prayers with lines
  // like "Repeat after me." are the usual victims), we re-ask it with the EXACT
  // missing words so it self-corrects, instead of just failing the row. Only give
  // up — and leave AB/JSON untouched — if it still won't reproduce every word.
  for (var round = 0; round < 3; round++) {
    var paragraphs = requestChunk_('PRAYER:\n' + rawText + correction);
    var diff = wordDiff_(rawText, paragraphs);
    if (!diff.dropped.length && !diff.added.length) return paragraphs;
    lastDiff = diffMessage_(diff);
    correction = '\n\nCORRECTION — your previous attempt did not reproduce the prayer exactly. '
      + 'Reproduce EVERY word and EVERY line verbatim, including instructional, rubric, or '
      + 'call-and-response lines such as "Repeat after me." Do not drop, add, or rephrase anything.'
      + (diff.dropped.length ? ' You omitted these words: ' + diff.dropped.slice(0, 20).join(', ') + '.' : '')
      + (diff.added.length ? ' You added these words: ' + diff.added.slice(0, 20).join(', ') + '.' : '');
  }
  throw new Error('Word mismatch after retries, not written (' + lastDiff + ').');
}

/**
 * One Gemini formatting request → cleaned paragraphs. Handles only the HTTP-level
 * retry (rate-limit / overload); the word-preservation retry lives in the caller.
 */
function requestChunk_(userText) {
  var url = 'https://generativelanguage.googleapis.com/v1beta/models/' +
            CONFIG.GEMINI_MODEL + ':generateContent?key=' + getApiKey_();

  var payload = {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [{ role: 'user', parts: [{ text: userText }] }],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: 'application/json',
      responseSchema: {
        type: 'object',
        properties: {
          paragraphs: {
            type: 'array',
            items: { type: 'array', items: { type: 'string' } }
          }
        },
        required: ['paragraphs']
      }
    }
  };

  // Retry on transient rate-limit / overload responses (429, 500, 503), which are
  // common on the Gemini free tier when several rows run back-to-back.
  var resp, code, body;
  for (var attempt = 0; attempt < 4; attempt++) {
    resp = UrlFetchApp.fetch(url, {
      method: 'post',
      contentType: 'application/json',
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    });
    code = resp.getResponseCode();
    body = resp.getContentText();
    if (code === 200) break;
    if (code === 429 || code === 500 || code === 503) {
      Utilities.sleep(2000 * (attempt + 1));  // 2s, 4s, 6s backoff
      continue;
    }
    break;  // other errors are not retryable
  }
  if (code !== 200) throw new Error('Gemini HTTP ' + code + ': ' + body.slice(0, 300));

  var data = JSON.parse(body);
  var text = data.candidates && data.candidates[0] &&
             data.candidates[0].content.parts[0].text;
  if (!text) throw new Error('Empty Gemini response.');

  // Strip ```json ... ``` fences defensively (schema mode usually omits them).
  text = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  var parsed = JSON.parse(text);
  var paragraphs = cleanGroups_(parsed.paragraphs);
  if (!paragraphs.length) throw new Error('No paragraphs returned.');
  return paragraphs;
}

/**
 * Word-multiset diff of source vs reformatted paragraphs (case-insensitive,
 * punctuation ignored). Returns { dropped:[...], added:[...] } of the distinct
 * words whose count fell / rose — used both to trigger a corrective retry and to
 * report the failure if the model still won't comply.
 */
function wordDiff_(rawText, paragraphs) {
  function tokens(s) {
    var m = String(s).toLowerCase().match(/[\p{L}\p{N}']+/gu);
    return m || [];
  }
  function counts(arr) {
    var c = {};
    arr.forEach(function (t) { c[t] = (c[t] || 0) + 1; });
    return c;
  }
  var srcC = counts(tokens(rawText));
  var out = [];
  paragraphs.forEach(function (lines) { out = out.concat(tokens(lines.join(' '))); });
  var outC = counts(out);

  var dropped = [], added = [];
  Object.keys(srcC).forEach(function (w) {
    if ((outC[w] || 0) < srcC[w]) dropped.push(w);
  });
  Object.keys(outC).forEach(function (w) {
    if ((srcC[w] || 0) < outC[w]) added.push(w);
  });
  return { dropped: dropped, added: added };
}

/** Short human-readable summary of a wordDiff_ result. */
function diffMessage_(diff) {
  var parts = [];
  if (diff.dropped.length) parts.push('dropped: ' + diff.dropped.slice(0, 12).join(', '));
  if (diff.added.length) parts.push('added: ' + diff.added.slice(0, 12).join(', '));
  return parts.join(' | ');
}

/** Trim lines, drop empty lines and empty groups. */
function cleanGroups_(groups) {
  if (!Array.isArray(groups)) return [];
  return groups
    .map(function (lines) {
      return (lines || []).map(function (l) { return String(l).trim(); })
                          .filter(function (l) { return l.length; });
    })
    .filter(function (lines) { return lines.length; });
}

// ---------------------------------------------------------------------------
// PROMPT — encodes the clause-level line / paragraph rules
// ---------------------------------------------------------------------------
var SYSTEM_PROMPT = [
  'You format an English prayer into a natural reading layout for both text-to-speech and on-screen',
  'display. Preserve every original word and all punctuation exactly — never rephrase, translate,',
  'add, or remove words. Output ONLY JSON with the single key "paragraphs".',
  'EVERY line counts — including instructional, rubric, or call-and-response lines',
  '(e.g. "Repeat after me.", leader/response cues, repeated refrains). Keep them ALL,',
  'verbatim and in their original order. Dropping any line is forbidden.',
  '',
  '"paragraphs" — an array of PARAGRAPHS; each paragraph is an array of LINES:',
  '   - Each line is a whole clause or a complete poetic line — NOT a short breath fragment.',
  '     Break a line only at a natural reading point: after a full clause, at major punctuation',
  '     (comma, semicolon, colon, period), or at a clear poetic line of the original. A typical',
  '     line is roughly 4–12 words and reads smoothly on one breath. NEVER break into 2–3 word',
  '     fragments — that destroys the spoken flow.',
  '   - Group lines into a SMALL number of paragraphs that follow the prayer\'s major sections /',
  '     sense units (usually matching the blank-line paragraphs of the original). Most prayers',
  '     have only 2–5 paragraphs. A paragraph break marks a real, meditative section pause — do',
  '     not create one at every line.',
  '   - A closing "Amen." sits on its own line as the final paragraph.',
  '',
  'EXAMPLE INPUT:',
  'Heavenly Father, divine source of all provision, I come before You with a grateful heart and thank You for the blessings I have already received. I ask You to pour out Your abundance. Amen.',
  '',
  'EXAMPLE OUTPUT:',
  '{"paragraphs":[',
  '["Heavenly Father, divine source of all provision,","I come before You with a grateful heart","and thank You for the blessings I have already received."],',
  '["I ask You to pour out Your abundance."],',
  '["Amen."]',
  ']}'
].join('\n');


// ===========================================================================
// FUNCTION 2 — TITLE (D) + DESCRIPTION (E)
// ===========================================================================
// Fills only the cells that are empty. If Title is missing, the model checks
// (via Google Search grounding) whether the prayer has an established/official
// title and uses it; otherwise it crafts a short German title from the incipit.
// Description is 1–2 German sentences in the house style. Existing values are
// never overwritten.
// ===========================================================================

function runTitleDescForSelectedRows() {
  runTitleDescForRows(getSelectedDataRows_());
}

/** Every data row where C has text but D or E is empty. */
function runTitleDescForMissingRows() {
  var sheet = SpreadsheetApp.getActiveSheet();
  var lastRow = sheet.getLastRow();
  var rows = [];
  for (var row = CONFIG.HEADER_ROWS + 1; row <= lastRow; row++) {
    var raw = String(sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue()).trim();
    var title = String(sheet.getRange(row, CONFIG.COL_TITLE).getValue()).trim();
    var desc = String(sheet.getRange(row, CONFIG.COL_DESCRIPTION).getValue()).trim();
    if (raw && (!title || !desc)) rows.push(row);
  }
  runTitleDescForRows(rows);
}

function runTitleDescForRows(rowNumbers) {
  if (!rowNumbers || !rowNumbers.length) {
    SpreadsheetApp.getActive().toast('No matching rows.', 'Prayer Tools', 5);
    return;
  }
  var sheet = SpreadsheetApp.getActiveSheet();
  var ok = 0, skip = 0, fail = 0, errors = [];

  rowNumbers.forEach(function (row) {
    var raw = String(sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue()).trim();
    if (!raw) return;

    var need = {
      title: !String(sheet.getRange(row, CONFIG.COL_TITLE).getValue()).trim(),
      desc:  !String(sheet.getRange(row, CONFIG.COL_DESCRIPTION).getValue()).trim()
    };
    if (!need.title && !need.desc) { skip++; return; }

    var ctx = {
      prayer: raw,
      author: String(sheet.getRange(row, CONFIG.COL_AUTHOR).getValue()).trim(),
      dates:  String(sheet.getRange(row, CONFIG.COL_ADDITION).getValue()).trim(),
      source: String(sheet.getRange(row, CONFIG.COL_SOURCE).getValue()).trim()
    };

    try {
      var out = generateTitleDescription_(ctx, need);
      if (need.title && out.title) sheet.getRange(row, CONFIG.COL_TITLE).setValue(out.title);
      if (need.desc && out.description) sheet.getRange(row, CONFIG.COL_DESCRIPTION).setValue(out.description);
      SpreadsheetApp.flush();
      ok++;
    } catch (e) {
      fail++;
      errors.push('Row ' + row + ': ' + e.message);
    }
  });

  var msg = ok + ' filled' + (skip ? ', ' + skip + ' already complete' : '') + (fail ? ', ' + fail + ' failed' : '');
  if (errors.length) Logger.log(errors.join('\n'));
  SpreadsheetApp.getActive().toast(msg, 'Prayer Tools', 8);
}

/**
 * Calls Gemini (with Google Search grounding when a title lookup is needed)
 * and returns { title?, description? } for the requested fields only.
 */
function generateTitleDescription_(ctx, need) {
  var wantList = [];
  if (need.title) wantList.push('"title"');
  if (need.desc) wantList.push('"description"');

  var rules = [
    'You curate an English prayer collection. Produce concise metadata in ENGLISH.',
    'Return ONLY a JSON object with exactly these keys: { ' + wantList.join(', ') + ' }.',
    'No markdown, no commentary.',
    ''
  ];

  if (need.title) {
    rules.push(
      'TITLE rules:',
      '- First determine whether this prayer is historically or liturgically known under an',
      '  ESTABLISHED title (a traditional, common name). If a well-known official title clearly',
      '  exists, return exactly that. Never invent a famous-sounding title that does not exist.',
      '- Otherwise, READ the prayer, understand what it is about, and give it a short, dignified',
      '  English title that captures its theme or heart — max ~6 words, no trailing punctuation.',
      ''
    );
  }
  if (need.desc) {
    rules.push(
      'DESCRIPTION rules:',
      '- READ the prayer and write what it is about, in 1–2 English sentences — never more.',
      '- Capture its origin/speaker (if known), its content, and its spiritual theme.',
      '- Plain prose, no surrounding quotes. Use the en dash "–" where fitting.',
      '- Match the tone of these real examples:',
      '  • "Solomon\'s prayer at the temple dedication from the First Book of Kings — a royal plea for God to keep his eyes open over the house that bears his name."',
      '  • "Augustine\'s moving confession of love from the Confessions — a sigh of relief at recognizing God. A classic prayer of repentance and longing for God."',
      '  • "The peace prayer attributed to Francis of Assisi — a commission to carry love, forgiveness, hope and light into the world."',
      ''
    );
  }

  var userParts = ['PRAYER:\n' + ctx.prayer];
  if (ctx.author) userParts.push('AUTHOR: ' + ctx.author + (ctx.dates ? ' (' + ctx.dates + ')' : ''));
  if (ctx.source) userParts.push('SOURCE: ' + ctx.source);
  userParts.push('Produce: ' + wantList.join(', '));

  var obj = callGeminiJsonGrounded_(rules.join('\n'), userParts.join('\n\n'), /*grounding=*/need.title);

  var result = {};
  if (need.title && obj.title) result.title = String(obj.title).trim().replace(/^["']|["']$/g, '');
  if (need.desc && obj.description) result.description = String(obj.description).trim().replace(/^["']|["']$/g, '');
  return result;
}

// ===========================================================================
// FUNCTION 3 — TONALITÄT (R) + SUITED FOR PRAYER STONE (S)
// ===========================================================================
// Pure text classification (no web lookup). Fills only empty cells; the model's
// answer is validated against the allowed value set before it is written.
//   Tonalität:    Zeitlos | Klassisch | Historisch | Zeitgemäß
//   Prayer Stone: Yes | No | Maybe
// ===========================================================================

var TONALITY_VALUES = ['Zeitlos', 'Klassisch', 'Historisch', 'Zeitgemäß'];
var STONE_VALUES = ['Yes', 'No', 'Maybe'];

function runTonalityForSelectedRows() {
  runTonalityForRows(getSelectedDataRows_());
}

/** Every data row where C has text but R or S is empty. */
function runTonalityForMissingRows() {
  var sheet = SpreadsheetApp.getActiveSheet();
  var lastRow = sheet.getLastRow();
  var rows = [];
  for (var row = CONFIG.HEADER_ROWS + 1; row <= lastRow; row++) {
    var raw = String(sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue()).trim();
    // "Needs filling" = the cell does NOT already hold a valid enum value.
    // This also self-corrects stray junk (e.g. a leftover ", ") and typos.
    var ton = normalizeEnum_(sheet.getRange(row, CONFIG.COL_TONALITY).getValue(), TONALITY_VALUES);
    var stone = normalizeEnum_(sheet.getRange(row, CONFIG.COL_PRAYER_STONE).getValue(), STONE_VALUES);
    if (raw && (!ton || !stone)) rows.push(row);
  }
  runTonalityForRows(rows);
}

function runTonalityForRows(rowNumbers) {
  if (!rowNumbers || !rowNumbers.length) {
    SpreadsheetApp.getActive().toast('No matching rows.', 'Prayer Tools', 5);
    return;
  }
  var sheet = SpreadsheetApp.getActiveSheet();
  var ok = 0, skip = 0, fail = 0, errors = [];

  rowNumbers.forEach(function (row) {
    var raw = String(sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue()).trim();
    if (!raw) return;

    // Fill unless the cell already holds a valid enum value (so a stray ", "
    // or a typo counts as "needs filling", but a real Yes/Klassisch is kept).
    var need = {
      tonality: !normalizeEnum_(sheet.getRange(row, CONFIG.COL_TONALITY).getValue(), TONALITY_VALUES),
      stone:    !normalizeEnum_(sheet.getRange(row, CONFIG.COL_PRAYER_STONE).getValue(), STONE_VALUES)
    };
    if (!need.tonality && !need.stone) { skip++; return; }

    try {
      var out = classifyTonalityStone_(raw, need);
      if (need.tonality && out.tonality) sheet.getRange(row, CONFIG.COL_TONALITY).setValue(out.tonality);
      if (need.stone && out.stone) sheet.getRange(row, CONFIG.COL_PRAYER_STONE).setValue(out.stone);
      SpreadsheetApp.flush();
      ok++;
    } catch (e) {
      fail++;
      errors.push('Row ' + row + ': ' + e.message);
    }
  });

  var msg = ok + ' filled' + (skip ? ', ' + skip + ' already complete' : '') + (fail ? ', ' + fail + ' failed' : '');
  if (errors.length) Logger.log(errors.join('\n'));
  SpreadsheetApp.getActive().toast(msg, 'Prayer Tools', 8);
}

/** Returns { tonality?, stone? } with values validated against the allowed sets. */
function classifyTonalityStone_(prayer, need) {
  var wantList = [];
  if (need.tonality) wantList.push('"tonality"');
  if (need.stone) wantList.push('"prayer_stone"');

  var rules = [
    'You classify prayers. Judge ONLY from the prayer text.',
    'Return ONLY a JSON object with exactly these keys: { ' + wantList.join(', ') + ' }.',
    'No markdown, no commentary.',
    ''
  ];

  if (need.tonality) {
    rules.push(
      'TONALITY — choose exactly one of: Zeitlos | Klassisch | Historisch | Zeitgemäß',
      '- Zeitlos: language that transcends any era — neither archaic nor trendy; universal,',
      '  enduring spiritual expression that feels at home in any century.',
      '- Klassisch: rooted in established liturgical/theological tradition; formal, dignified,',
      '  structured — the language of church worship and confessional prayer books.',
      '- Historisch: deliberately older/archaic forms (e.g. "du wollest", "auf daß", old',
      '  spellings/inflections); reverence through historical distance (ancient or Reformation era).',
      '- Zeitgemäß: modern, accessible, conversational language for people today; avoids formal',
      '  or archaic phrasing in favor of clarity and relatability.',
      ''
    );
  }
  if (need.stone) {
    rules.push(
      'PRAYER_STONE — is this prayer suited to be read aloud BY ANOTHER PERSON? choose: Yes | No | Maybe',
      '- Yes: it could naturally be prayed by someone other than the author. Most well-known,',
      '  general prayers fall here.',
      '- No: very strongly personal in tone — the author speaks about intimate, individual matters,',
      '  shares deeply personal things, or it is highly poetic/private.',
      '- Maybe: genuinely uncertain — the judgement is not clear-cut.',
      ''
    );
  }

  var obj = callGeminiJsonGrounded_(rules.join('\n'), 'PRAYER:\n' + prayer, /*grounding=*/false);

  var result = {};
  if (need.tonality) {
    var t = normalizeEnum_(obj.tonality, TONALITY_VALUES);
    if (!t) throw new Error('Invalid tonality: ' + obj.tonality);
    result.tonality = t;
  }
  if (need.stone) {
    var s = normalizeEnum_(obj.prayer_stone, STONE_VALUES);
    if (!s) throw new Error('Invalid prayer_stone: ' + obj.prayer_stone);
    result.stone = s;
  }
  return result;
}

/** Case-insensitive match of an LLM value against an allowed list; null if no match. */
function normalizeEnum_(value, allowed) {
  if (value == null) return null;
  var v = String(value).trim().toLowerCase();
  for (var i = 0; i < allowed.length; i++) {
    if (allowed[i].toLowerCase() === v) return allowed[i];
  }
  return null;
}

// ===========================================================================
// FUNCTION 4 — CATEGORIES (Y..AA) + KEYWORDS (T..X)
// ===========================================================================
// Categories: 1–3 from the live Categories tab (col B), based on the DESCRIPTION (+ text).
// Keywords:   2–5 from the live "Keywords" tab, based on the prayer TEXT.
// Never invents values. Fills only rows that don't already hold valid values
// (so stray junk like ", " is self-corrected). Writing overwrites the whole
// T..X / Y..AA span and clears leftover cells.
// ===========================================================================

var _kwCache = null;
var _catCache = null;

/** Diagnostic: shows all tab names and what the script reads as the allowed keywords. */
function debugKeywords() {
  var ui = SpreadsheetApp.getUi();
  var ss = SpreadsheetApp.getActive();
  var tabNames = ss.getSheets().map(function (s) { return '"' + s.getName() + '"'; }).join(', ');
  var msg = 'CONFIG.KEYWORDS_TAB = "' + CONFIG.KEYWORDS_TAB + '" (col ' + CONFIG.KEYWORDS_COL + ')\n\n' +
            'Tabs in this spreadsheet:\n' + tabNames + '\n\n';
  try {
    _kwCache = null; // force a fresh read
    var kw = getAllowedKeywords_();
    msg += 'Read ' + kw.length + ' keywords. First 15:\n' + kw.slice(0, 15).join(', ');
  } catch (e) {
    msg += '❌ ERROR reading keyword list:\n' + e.message;
  }
  ui.alert('Keyword list diagnostic', msg, ui.ButtonSet.OK);
}

/** Diagnostic: shows all tab names and what the script reads as the allowed categories. */
function debugCategories() {
  var ui = SpreadsheetApp.getUi();
  var ss = SpreadsheetApp.getActive();
  var tabNames = ss.getSheets().map(function (s) { return '"' + s.getName() + '"'; }).join(', ');
  var msg = 'CONFIG.CATEGORIES_TAB = "' + CONFIG.CATEGORIES_TAB + '" (col ' + CONFIG.CATEGORIES_COL + ')\n\n' +
            'Tabs in this spreadsheet:\n' + tabNames + '\n\n';
  try {
    _catCache = null; // force a fresh read
    var cats = getAllowedCategories_();
    msg += 'Read ' + cats.length + ' categories:\n' + cats.join(', ');
  } catch (e) {
    msg += '❌ ERROR reading category list:\n' + e.message;
  }
  ui.alert('Category list diagnostic', msg, ui.ButtonSet.OK);
}

function runCatKwForSelectedRows() {
  runCatKwForRows(getSelectedDataRows_());
}

/** Every data row with prayer text that has no valid keyword OR no valid category yet. */
function runCatKwForMissingRows() {
  var sheet = SpreadsheetApp.getActiveSheet();
  var allowedKw = getAllowedKeywords_();
  var allowedCat = getAllowedCategories_();
  var lastRow = sheet.getLastRow();
  var rows = [];
  for (var row = CONFIG.HEADER_ROWS + 1; row <= lastRow; row++) {
    var raw = String(sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue()).trim();
    if (!raw) continue;
    var need = rowCatKwNeed_(sheet, row, allowedKw, allowedCat);
    if (need.cat || need.kw) rows.push(row);
  }
  runCatKwForRows(rows);
}

function runCatKwForRows(rowNumbers) {
  if (!rowNumbers || !rowNumbers.length) {
    SpreadsheetApp.getActive().toast('No matching rows.', 'Prayer Tools', 5);
    return;
  }
  var sheet = SpreadsheetApp.getActiveSheet();
  var allowedKw = getAllowedKeywords_();
  var allowedCat = getAllowedCategories_();
  var ok = 0, skip = 0, fail = 0, errors = [];

  rowNumbers.forEach(function (row) {
    var raw = String(sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue()).trim();
    if (!raw) return;
    var desc = String(sheet.getRange(row, CONFIG.COL_DESCRIPTION).getValue()).trim();

    var need = rowCatKwNeed_(sheet, row, allowedKw, allowedCat);
    if (!need.cat && !need.kw) { skip++; return; }

    try {
      var out = classifyCatKw_(raw, desc, allowedKw, allowedCat, need);
      if (need.cat) writeListToColumns_(sheet, row, CONFIG.COL_CAT_FIRST, CONFIG.COL_CAT_LAST, out.categories);
      if (need.kw)  writeListToColumns_(sheet, row, CONFIG.COL_KW_FIRST, CONFIG.COL_KW_LAST, out.keywords);
      SpreadsheetApp.flush();
      ok++;
    } catch (e) {
      fail++;
      errors.push('Row ' + row + ': ' + e.message);
    }
  });

  var msg = ok + ' filled' + (skip ? ', ' + skip + ' already complete' : '') + (fail ? ', ' + fail + ' failed' : '');
  if (errors.length) Logger.log(errors.join('\n'));
  SpreadsheetApp.getActive().toast(msg, 'Prayer Tools', 8);
}

/** A row "needs" categories/keywords if it holds zero valid values in that span. */
function rowCatKwNeed_(sheet, row, allowedKw, allowedCat) {
  var cats = sheet.getRange(row, CONFIG.COL_CAT_FIRST, 1, CONFIG.COL_CAT_LAST - CONFIG.COL_CAT_FIRST + 1).getValues()[0];
  var kws = sheet.getRange(row, CONFIG.COL_KW_FIRST, 1, CONFIG.COL_KW_LAST - CONFIG.COL_KW_FIRST + 1).getValues()[0];
  var hasCat = cats.some(function (v) { return !!normalizeEnum_(v, allowedCat); });
  var hasKw = kws.some(function (v) { return !!normalizeEnum_(v, allowedKw); });
  return { cat: !hasCat, kw: !hasKw };
}

/** Returns { categories:[...], keywords:[...] }, each validated against its allowed list. */
function classifyCatKw_(prayer, description, allowedKw, allowedCat, need) {
  var wantList = [];
  if (need.cat) wantList.push('"categories"');
  if (need.kw) wantList.push('"keywords"');

  // Categories the AI may actually choose from — the curated list minus the
  // hand-attributed ones (Rosary, Prayer Patterns). Used for BOTH the prompt and
  // the validation below, so an excluded category is never written even if the
  // model returns it anyway.
  var excludeLower = (CONFIG.CATEGORIES_AI_EXCLUDE || []).map(function (x) { return String(x).toLowerCase(); });
  var offeredCat = allowedCat.filter(function (c) {
    return excludeLower.indexOf(String(c).toLowerCase()) === -1;
  });

  var rules = [
    'You tag prayers for a curated collection.',
    'Return ONLY a JSON object with exactly these keys: { ' + wantList.join(', ') + ' }.',
    'No markdown, no commentary.',
    ''
  ];
  if (need.cat) {
    rules.push(
      'CATEGORIES — assign EVERY category that genuinely applies, usually 2–3 (up to ' + CONFIG.MAX_CATEGORIES + '),',
      'based mainly on the DESCRIPTION (and the prayer). Give the clearest primary category first,',
      'then add any secondary categories that also fit well — most prayers touch more than one theme.',
      'Return just one category ONLY when no other genuinely applies; do not pad with weak fits.',
      'Choose ONLY from this exact list, copied verbatim:',
      offeredCat.join(' | '),
      'Order by best fit first. Never invent a category.',
      ''
    );
  }
  if (need.kw) {
    rules.push(
      'KEYWORDS — pick 2 to ' + CONFIG.MAX_KEYWORDS + ' that capture what the prayer is about,',
      'based on the TEXT. Choose ONLY from this exact allowed list, copied verbatim:',
      allowedKw.join(' | '),
      'Favor the most SPECIFIC, distinctive keywords that name this prayer\'s concrete theme',
      'over broad, generic ones: if a precise keyword fits (e.g. "Prosperity", "Illness",',
      '"Morning prayer"), prefer it to a vague catch-all (e.g. "Trust", "Petition") that could',
      'apply to almost any prayer. Use a generic keyword only when no specific one fits.',
      'Order by relevance first. Fewer than ' + CONFIG.MAX_KEYWORDS + ' is fine; never invent a keyword',
      'and never return one that is not in the list above.',
      ''
    );
  }

  var userText = 'PRAYER:\n' + prayer + (description ? '\n\nDESCRIPTION:\n' + description : '');
  var obj = callGeminiJsonGrounded_(rules.join('\n'), userText, /*grounding=*/false);

  var result = {};
  if (need.cat) {
    result.categories = validateList_(obj.categories, offeredCat, CONFIG.MAX_CATEGORIES);
    if (!result.categories.length) throw new Error('No valid category returned.');
  }
  if (need.kw) {
    result.keywords = validateList_(obj.keywords, allowedKw, CONFIG.MAX_KEYWORDS);
    if (!result.keywords.length) throw new Error('No valid keyword returned.');
  }
  return result;
}

/** Maps an LLM array onto the allowed list (case-insensitive), dedupes, caps length. */
function validateList_(arr, allowed, max) {
  if (!Array.isArray(arr)) return [];
  var out = [], seen = {};
  arr.forEach(function (v) {
    var m = normalizeEnum_(v, allowed);
    if (m && !seen[m]) { seen[m] = true; out.push(m); }
  });
  return out.slice(0, max);
}

/** Reads the allowed keyword list live from the Keywords tab (column A). */
function getAllowedKeywords_() {
  if (_kwCache) return _kwCache;
  var tab = getSheetByNameCI_(CONFIG.KEYWORDS_TAB);
  if (!tab) {
    var names = SpreadsheetApp.getActive().getSheets().map(function (s) { return '"' + s.getName() + '"'; });
    throw new Error('Keywords tab "' + CONFIG.KEYWORDS_TAB + '" not found. Tabs are: ' + names.join(', '));
  }
  var last = tab.getLastRow();
  if (last < 1) throw new Error('Keywords tab "' + tab.getName() + '" is empty.');
  var vals = tab.getRange(1, CONFIG.KEYWORDS_COL, last, 1).getValues();
  var out = [], seen = {};
  vals.forEach(function (r, i) {
    var v = String(r[0]).trim();
    if (!v) return;
    // Skip a header cell only if it's literally a "Keyword(s)" label in the first row.
    if (i === 0 && /^keywords?$/i.test(v)) return;
    if (!seen[v.toLowerCase()]) { seen[v.toLowerCase()] = true; out.push(v); }
  });
  if (!out.length) throw new Error('No keywords found in tab "' + tab.getName() + '" column ' + CONFIG.KEYWORDS_COL + '.');
  _kwCache = out;
  return out;
}

/** Reads the allowed category list live from the Categories tab (column B). */
function getAllowedCategories_() {
  if (_catCache) return _catCache;
  var tab = getSheetByNameCI_(CONFIG.CATEGORIES_TAB);
  if (!tab) {
    var names = SpreadsheetApp.getActive().getSheets().map(function (s) { return '"' + s.getName() + '"'; });
    throw new Error('Categories tab "' + CONFIG.CATEGORIES_TAB + '" not found. Tabs are: ' + names.join(', '));
  }
  var last = tab.getLastRow();
  if (last < 1) throw new Error('Categories tab "' + tab.getName() + '" is empty.');
  var vals = tab.getRange(1, CONFIG.CATEGORIES_COL, last, 1).getValues();
  var out = [], seen = {};
  vals.forEach(function (r, i) {
    var v = String(r[0]).trim();
    if (!v) return;
    // Skip a header cell in the first row (e.g. "Category", "Categories",
    // "English category to use") — any first-row label mentioning "categor".
    if (i === 0 && /categor/i.test(v)) return;
    if (!seen[v.toLowerCase()]) { seen[v.toLowerCase()] = true; out.push(v); }
  });
  if (!out.length) throw new Error('No categories found in tab "' + tab.getName() + '" column ' + CONFIG.CATEGORIES_COL + '.');
  _catCache = out;
  return out;
}

/** Case-insensitive, trim-tolerant sheet lookup. */
function getSheetByNameCI_(name) {
  var want = String(name).trim().toLowerCase();
  var sheets = SpreadsheetApp.getActive().getSheets();
  for (var i = 0; i < sheets.length; i++) {
    if (sheets[i].getName().trim().toLowerCase() === want) return sheets[i];
  }
  return null;
}

/** Writes values into firstCol..lastCol on a row, clearing any leftover cells in the span. */
function writeListToColumns_(sheet, row, firstCol, lastCol, values) {
  var span = lastCol - firstCol + 1;
  var rowVals = [];
  for (var i = 0; i < span; i++) rowVals.push(i < values.length ? values[i] : '');
  sheet.getRange(row, firstCol, 1, span).setValues([rowVals]);
}

// ===========================================================================
// FUNCTION 5 — BUILD JSON (selected rows → prayer objects, sorted by ID)
// ===========================================================================
// Pure assembly, no LLM. For each selected row it builds the prayer object in
// the app's schema, writes it into the "JSON Output" column (AD), and shows the
// combined array of all selected prayers — sorted by ID — in a copyable dialog.
// holiday / theology / estimatedMinutes are always null for now.
// ===========================================================================

function runBuildJsonForSelectedRows() {
  var sheet = SpreadsheetApp.getActiveSheet();
  var rows = getSelectedDataRows_();
  var objs = [];

  rows.forEach(function (row) {
    var obj = buildPrayerObject_(sheet, row);
    if (!obj) return;
    sheet.getRange(row, CONFIG.COL_JSON_OUTPUT).setValue(JSON.stringify(obj, null, 2));
    objs.push(obj);
  });

  if (!objs.length) {
    SpreadsheetApp.getActive().toast('No rows with an ID + text selected.', 'Prayer Tools', 6);
    return;
  }

  objs.sort(function (a, b) { return compareIds_(a.id, b.id); });
  SpreadsheetApp.flush();
  showJsonDialog_(objs);
}

/** Builds one prayer object from a row, or null if it lacks an ID or text. */
function buildPrayerObject_(sheet, row) {
  var id = String(sheet.getRange(row, CONFIG.COL_ID).getValue()).trim();
  var text = String(sheet.getRange(row, CONFIG.COL_JSON_FORMAT).getValue());
  if (!id || !text.trim()) return null;

  var title = String(sheet.getRange(row, CONFIG.COL_TITLE).getValue()).trim();
  var desc = String(sheet.getRange(row, CONFIG.COL_DESCRIPTION).getValue()).trim();
  var author = String(sheet.getRange(row, CONFIG.COL_AUTHOR).getValue()).trim();

  var tags = rowValues_(sheet, row, CONFIG.COL_KW_FIRST, CONFIG.COL_KW_LAST);
  var cats = rowValues_(sheet, row, CONFIG.COL_CAT_FIRST, CONFIG.COL_CAT_LAST);
  // The style tag (AE: Modern | Poetic | Classic) joins the same category list.
  var style = normalizeEnum_(sheet.getRange(row, CONFIG.COL_STYLE).getValue(), STYLE_VALUES);
  if (style) cats.push(style);
  var category = cats.length === 0 ? null : (cats.length === 1 ? cats[0] : cats);

  // Build in this exact key order to match the existing JSON file.
  return {
    id: id,
    title: title,
    shortDescription: desc || null,
    author: author || null,
    text: text,
    tags: tags,
    category: category,
    holiday: null,
    theology: null,
    estimatedMinutes: null,
    audio: { male: null, female: null }
  };
}

/** Non-empty trimmed values across a column span on one row. */
function rowValues_(sheet, row, firstCol, lastCol) {
  var vals = sheet.getRange(row, firstCol, 1, lastCol - firstCol + 1).getValues()[0];
  return vals.map(function (v) { return String(v).trim(); })
             .filter(function (v) { return v.length; });
}

/** Sort comparator: pure-integer ids numerically, otherwise lexicographically. */
function compareIds_(a, b) {
  var na = /^\d+$/.test(a), nb = /^\d+$/.test(b);
  if (na && nb) return Number(a) - Number(b);
  if (na) return -1;          // numeric ids before text ids
  if (nb) return 1;
  return a < b ? -1 : (a > b ? 1 : 0);
}

/** Shows the combined JSON array in a copyable modal (warns on duplicate ids). */
function showJsonDialog_(objs) {
  var json = JSON.stringify(objs, null, 2);

  var seen = {}, dups = {};
  objs.forEach(function (o) { if (seen[o.id]) dups[o.id] = true; seen[o.id] = true; });
  var dupIds = Object.keys(dups);
  var warn = dupIds.length
    ? '<p style="color:#b00;font-weight:bold">⚠ Duplicate id(s): ' + dupIds.join(', ') + '</p>'
    : '';

  var safe = json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  var html =
    '<div style="font-family:-apple-system,Arial,sans-serif">' +
    '<p>' + objs.length + ' prayer(s), sorted by id. Select all (Cmd+A) and copy:</p>' + warn +
    '<textarea id="t" style="width:100%;height:380px;font-family:monospace;font-size:12px">' + safe + '</textarea>' +
    '<p><button onclick="var t=document.getElementById(\'t\');t.focus();t.select();document.execCommand(\'copy\')">Copy to clipboard</button></p>' +
    '</div>';

  var out = HtmlService.createHtmlOutput(html).setWidth(720).setHeight(520);
  SpreadsheetApp.getUi().showModalDialog(out, 'Prayer JSON');
}

// ===========================================================================
// FUNCTION 6 — STYLE (AE): Modern | Poetic | Classic
// ===========================================================================
// One coarse style tag per prayer, independent of Tonalität (R).
//   - Classic: traditional/liturgical, formal register, historical canon.
//   - Modern:  contemporary, accessible, conversational language for today.
//   - Poetic:  overtly verse/lyrical, imagery-driven — only when that poetic
//              form is the DEFINING feature (the small, distinct group).
// Hard rule: any prayer whose categories (Y..AA) include "Klassiker" is set to
// Classic without a model call. No prayer IDs are skipped in this edition.
// Fills only rows that don't already hold a valid value (self-corrects junk).
// ===========================================================================

var STYLE_VALUES = ['Modern', 'Poetic', 'Classic'];

/** English edition: no ID range is skipped by the style classification. */
function isStyleSkipped_(id) {
  return false;
}

function runStyleForSelectedRows() {
  runStyleForRows(getSelectedDataRows_());
}

/** Every data row with prayer text whose AE isn't a valid value yet. */
function runStyleForMissingRows() {
  var sheet = SpreadsheetApp.getActiveSheet();
  var lastRow = sheet.getLastRow();
  var rows = [];
  for (var row = CONFIG.HEADER_ROWS + 1; row <= lastRow; row++) {
    var raw = String(sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue()).trim();
    if (!raw) continue;
    var id = String(sheet.getRange(row, CONFIG.COL_ID).getValue()).trim();
    if (isStyleSkipped_(id)) continue;
    var style = normalizeEnum_(sheet.getRange(row, CONFIG.COL_STYLE).getValue(), STYLE_VALUES);
    if (!style) rows.push(row);
  }
  runStyleForRows(rows);
}

function runStyleForRows(rowNumbers) {
  if (!rowNumbers || !rowNumbers.length) {
    SpreadsheetApp.getActive().toast('No matching rows.', 'Prayer Tools', 5);
    return;
  }
  var sheet = SpreadsheetApp.getActiveSheet();
  var ok = 0, skip = 0, fail = 0, errors = [];

  rowNumbers.forEach(function (row) {
    var raw = String(sheet.getRange(row, CONFIG.COL_PRAYER_TEXT).getValue()).trim();
    if (!raw) return;

    var id = String(sheet.getRange(row, CONFIG.COL_ID).getValue()).trim();
    if (isStyleSkipped_(id)) { skip++; return; }

    // Already holds a valid value → leave it (self-corrects only invalid/empty cells).
    if (normalizeEnum_(sheet.getRange(row, CONFIG.COL_STYLE).getValue(), STYLE_VALUES)) { skip++; return; }

    try {
      // Hard rule: a prayer in the classic-collection category is Classic — no model call.
      // Disabled when STYLE_CLASSIC_CATEGORY is '' (English default until you set it).
      var isClassicCollection = false;
      if (CONFIG.STYLE_CLASSIC_CATEGORY) {
        var cats = rowValues_(sheet, row, CONFIG.COL_CAT_FIRST, CONFIG.COL_CAT_LAST);
        var want = CONFIG.STYLE_CLASSIC_CATEGORY.trim().toLowerCase();
        isClassicCollection = cats.some(function (c) { return String(c).trim().toLowerCase() === want; });
      }
      var style = isClassicCollection ? 'Classic' : classifyStyle_(raw);
      sheet.getRange(row, CONFIG.COL_STYLE).setValue(style);
      SpreadsheetApp.flush();
      ok++;
    } catch (e) {
      fail++;
      errors.push('Row ' + row + ': ' + e.message);
    }
  });

  var msg = ok + ' filled' + (skip ? ', ' + skip + ' skipped' : '') + (fail ? ', ' + fail + ' failed' : '');
  if (errors.length) {
    Logger.log(errors.join('\n'));
    msg += '\n' + errors[0];   // surface the first failure so it isn't silently hidden
  }
  SpreadsheetApp.getActive().toast(msg, 'Prayer Tools', 12);
}

/** Classifies one prayer's style, validated against STYLE_VALUES. */
function classifyStyle_(prayer) {
  var rules = [
    'You classify an English prayer by its overall STYLE. Judge ONLY from the prayer text.',
    'Return ONLY a JSON object: { "style": "..." } with exactly one of: Modern | Poetic | Classic.',
    'No markdown, no commentary.',
    '',
    'STYLE — choose exactly one:',
    '- Classic: traditional, liturgical or historical prayers; formal, dignified register;',
    '  the language of church worship, prayer books and the established canon.',
    '- Modern: contemporary, accessible, conversational language written for people today;',
    '  plain and relatable, not archaic or heavily formal.',
    '- Poetic: choose ONLY when the prayer is overtly verse-like / lyrical and that poetic',
    '  character — rich imagery, metaphor, rhythmic or stanzaic form — is its DEFINING feature.',
    '  If a prayer is merely a little expressive but otherwise classic or modern in register,',
    '  do NOT pick Poetic; pick Classic or Modern instead. Poetic is the rare, distinct case.'
  ];

  var obj = callGeminiJsonGrounded_(rules.join('\n'), 'PRAYER:\n' + prayer, /*grounding=*/false);
  var s = normalizeEnum_(obj.style, STYLE_VALUES);
  if (!s) throw new Error('Invalid style: ' + obj.style);
  return s;
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/** Distinct, sorted data-row numbers from the current selection (skips header). */
function getSelectedDataRows_() {
  var sheet = SpreadsheetApp.getActiveSheet();
  var ranges = sheet.getActiveRangeList().getRanges();
  var rows = {};
  ranges.forEach(function (r) {
    for (var i = 0; i < r.getNumRows(); i++) {
      var row = r.getRow() + i;
      if (row > CONFIG.HEADER_ROWS) rows[row] = true;
    }
  });
  return Object.keys(rows).map(Number).sort(function (a, b) { return a - b; });
}

/**
 * Gemini call that returns a parsed JSON object. When grounding is true,
 * Google Search is enabled (so it can look up official titles) — note that
 * grounding cannot be combined with strict JSON response mode, so we ask for
 * JSON in the prompt and extract it robustly from the text.
 */
function callGeminiJsonGrounded_(systemPrompt, userText, grounding) {
  var url = 'https://generativelanguage.googleapis.com/v1beta/models/' +
            CONFIG.GEMINI_MODEL + ':generateContent?key=' + getApiKey_();

  var payload = {
    systemInstruction: { parts: [{ text: systemPrompt }] },
    contents: [{ role: 'user', parts: [{ text: userText }] }],
    generationConfig: { temperature: 0.3 }
  };
  if (grounding) payload.tools = [{ google_search: {} }];

  var resp = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });
  var code = resp.getResponseCode();
  if (code !== 200) throw new Error('Gemini HTTP ' + code + ': ' + resp.getContentText().slice(0, 300));

  var data = JSON.parse(resp.getContentText());
  var text = data.candidates && data.candidates[0] &&
             data.candidates[0].content.parts.map(function (p) { return p.text || ''; }).join('');
  if (!text) throw new Error('Empty Gemini response.');
  return extractJson_(text);
}

/** Pull the first {...} JSON object out of an LLM reply, tolerating fences/prose. */
function extractJson_(text) {
  var t = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  var start = t.indexOf('{');
  var end = t.lastIndexOf('}');
  if (start === -1 || end === -1 || end < start) throw new Error('No JSON in response: ' + t.slice(0, 200));
  return JSON.parse(t.slice(start, end + 1));
}
