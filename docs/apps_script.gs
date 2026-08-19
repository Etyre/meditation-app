/**
 * Google Apps Script webhook that receives session logs from the meditation
 * app and appends them as rows to the spreadsheet it is bound to.
 *
 * Setup (one time, ~2 minutes):
 *  1. Create a Google Sheet (e.g. "Meditation Log").
 *  2. Extensions → Apps Script, delete the boilerplate, paste this file.
 *  3. Deploy → New deployment → type "Web app".
 *       - Execute as: Me
 *       - Who has access: Anyone (the URL is an unguessable secret;
 *         only someone with the exact URL can post)
 *  4. Copy the web app URL (ends in /exec) and paste it into the app's
 *     Settings → Google Sheets.
 *
 * To update the script later: paste changes, then Deploy → Manage
 * deployments → edit → New version (the URL stays the same).
 */

var HEADER = [
  'Started at', 'Ended at', 'Planned (min)', 'Meditated (min)',
  'Overtime (min)', 'Included overtime', 'Aborted', 'Open-ended',
  'Mean HR', 'Min HR', 'Max HR', 'Mean RR (ms)', 'SDNN (ms)', 'RMSSD (ms)',
  'ln(RMSSD)', 'HRV score', 'RR count', 'RR intervals (ms)', 'HR series',
];

function doPost(e) {
  var data = JSON.parse(e.postData.contents);
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheets()[0];

  // Answer columns are created dynamically from the question text, so you
  // can change your questions without touching this script.
  var answers = data.answers || {};
  var questions = Object.keys(answers);

  if (sheet.getLastRow() === 0) {
    sheet.appendRow(HEADER.concat(questions));
  }

  // Add columns for any questions not yet in the header row.
  var lastCol = sheet.getLastColumn();
  var header = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
  questions.forEach(function (q) {
    if (header.indexOf(q) === -1) {
      sheet.getRange(1, header.length + 1).setValue(q);
      header.push(q);
    }
  });

  var row = [
    data.startedAt, data.endedAt, data.plannedMinutes, data.meditatedMinutes,
    data.overtimeMinutes, data.includedOvertime, data.aborted, data.openEnded,
    data.meanHr, data.minHr, data.maxHr, data.meanRrMs, data.sdnnMs,
    data.rmssdMs, data.lnRmssd, data.hrvScore, data.rrCount,
    data.rrIntervalsMs, data.hrSeries,
  ];
  // Place each answer under its question's column.
  header.slice(HEADER.length).forEach(function (q) {
    row.push(answers[q] !== undefined ? answers[q] : '');
  });

  sheet.appendRow(row);
  return ContentService.createTextOutput(
    JSON.stringify({ ok: true })
  ).setMimeType(ContentService.MimeType.JSON);
}
