/**
 * Google Apps Script webhook that receives session logs from the meditation
 * app and appends them as rows to the spreadsheet it is bound to.
 *
 * Setup (one time, ~2 minutes):
 *  1. Create a Google Sheet (e.g. "Meditation Log").
 *  2. Extensions → Apps Script, delete the boilerplate, paste this file.
 *  3. Project Settings (gear icon) → Script properties → Add property:
 *       Property: SECRET   Value: any long random string
 *     Posts that don't carry this exact value are rejected. (Leaving it
 *     unset accepts any post that reaches the URL.)
 *  4. Deploy → New deployment → type "Web app".
 *       - Execute as: Me
 *       - Who has access: Anyone (the URL is unguessable, and the SECRET
 *         above is checked on every post)
 *  5. Copy the web app URL (ends in /exec) and paste it into the app's
 *     Settings → Google Sheets, along with the same secret.
 *
 * To update the script later: paste changes, then Deploy → Manage
 * deployments → edit → New version (the URL and secret stay the same).
 */

var HEADER = [
  'Started at', 'Ended at', 'Planned (min)', 'Meditated (min)',
  'Overtime (min)', 'Included overtime', 'Aborted', 'Open-ended',
  'Mean HR', 'Min HR', 'Max HR', 'Mean RR (ms)', 'SDNN (ms)', 'RMSSD (ms)',
  'ln(RMSSD)', 'HRV score', 'RR count', 'RR intervals (ms)', 'HR series',
  'Baseline HR', 'Baseline HR window (s)', 'First 20s HR',
];

// A Sheets cell holds at most 50,000 characters. Long sessions can exceed
// that in the raw RR/HR columns, so oversized values are split across
// continuation columns named "<header> (cont. 2)", "<header> (cont. 3)", …
// Concatenating a column with its continuations restores the exact value.
var CELL_LIMIT = 45000;

function doPost(e) {
  var data = JSON.parse(e.postData.contents);

  var secret = PropertiesService.getScriptProperties().getProperty('SECRET');
  if (secret && data.secret !== secret) {
    return ContentService.createTextOutput(
      JSON.stringify({ ok: false, error: 'bad secret' })
    ).setMimeType(ContentService.MimeType.JSON);
  }
  delete data.secret;

  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheets()[0];
  var answers = data.answers || {};

  // header name → cell value. Answer columns are created dynamically from
  // the question text, so questions can change without touching this script.
  var values = {};
  var baseValues = [
    data.startedAt, data.endedAt, data.plannedMinutes, data.meditatedMinutes,
    data.overtimeMinutes, data.includedOvertime, data.aborted, data.openEnded,
    data.meanHr, data.minHr, data.maxHr, data.meanRrMs, data.sdnnMs,
    data.rmssdMs, data.lnRmssd, data.hrvScore, data.rrCount,
    data.rrIntervalsMs, data.hrSeries,
    data.baselineHr, data.baselineHrSeconds, data.first20sHr,
  ];
  HEADER.forEach(function (name, i) { values[name] = baseValues[i]; });
  Object.keys(answers).forEach(function (q) { values[q] = answers[q]; });

  // Split any oversized value into continuation entries.
  Object.keys(values).forEach(function (name) {
    var v = values[name];
    if (typeof v === 'string' && v.length > CELL_LIMIT) {
      for (var part = 2, s = CELL_LIMIT; s < v.length; part++, s += CELL_LIMIT) {
        values[name + ' (cont. ' + part + ')'] = v.slice(s, s + CELL_LIMIT);
      }
      values[name] = v.slice(0, CELL_LIMIT);
    }
  });

  // Make sure every value has a header column, extending the header row
  // with any new names (new questions, new continuation columns).
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(HEADER);
  }
  var lastCol = sheet.getLastColumn();
  var header = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
  Object.keys(values).forEach(function (name) {
    if (header.indexOf(name) === -1) {
      sheet.getRange(1, header.length + 1).setValue(name);
      header.push(name);
    }
  });

  // Emit the row in header order.
  var row = header.map(function (name) {
    return values[name] !== undefined ? values[name] : '';
  });
  sheet.appendRow(row);

  return ContentService.createTextOutput(
    JSON.stringify({ ok: true })
  ).setMimeType(ContentService.MimeType.JSON);
}
