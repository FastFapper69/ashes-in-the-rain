// Crash reports for Ashes in the Rain. When a phone's browser kills the page (out of memory) it gets
// no chance to say so; so the game leaves breadcrumbs in localStorage as it runs, and the next load
// sends the last ones home if the page did not go away cleanly. Script errors are sent as they happen.
(function () {
  var URL_ = 'https://mpxfppuigwvwlfhsnbgr.supabase.co/rest/v1/ashes_reports';
  var KEY = 'sb_publishable_X7rB8j45EHq79TnlzSxxsw_slxNAD8G';
  var BUILD = '__BUILD__';
  var sent = 0;
  function now() { return new Date().toISOString().substr(11, 12); }
  function crumbs() { try { return JSON.parse(localStorage.getItem('ashes_crumbs') || '[]'); } catch (e) { return []; } }
  function crumb(t) {
    try {
      var c = crumbs(); c.push(now() + ' ' + String(t).substr(0, 400));
      if (c.length > 80) c = c.slice(c.length - 80);
      localStorage.setItem('ashes_crumbs', JSON.stringify(c));
    } catch (e) {}
  }
  function send(kind, extra) {
    if (sent >= 6) return; sent++;
    var body = { kind: kind, build: BUILD, device: navigator.userAgent.substr(0, 300),
      report: { crumbs: crumbs(), extra: extra || null, screen: [screen.width, screen.height, window.devicePixelRatio] } };
    try {
      fetch(URL_, { method: 'POST', keepalive: true, headers: { 'apikey': KEY, 'Authorization': 'Bearer ' + KEY,
        'Content-Type': 'application/json', 'Prefer': 'return=minimal' }, body: JSON.stringify(body) }).catch(function () {});
    } catch (e) {}
  }
  window.ashesCrumb = crumb;
  window.ashesReport = send;
  // the last run never said goodbye: it was killed
  try {
    var prev = localStorage.getItem('ashes_alive');
    var prevBuild = localStorage.getItem('ashes_build');
    if (prev === '1' && crumbs().length) {
      send('crash', { previous_build: prevBuild });
    }
    localStorage.setItem('ashes_crumbs', '[]');
    localStorage.setItem('ashes_alive', '1');
    localStorage.setItem('ashes_build', BUILD);
  } catch (e) {}
  crumb('boot ' + BUILD);
  document.addEventListener('visibilitychange', function () {
    try { localStorage.setItem('ashes_alive', document.hidden ? '0' : '1'); } catch (e) {}
    crumb(document.hidden ? 'hidden' : 'visible');
  });
  window.addEventListener('pagehide', function () { try { localStorage.setItem('ashes_alive', '0'); } catch (e) {} });
  window.addEventListener('error', function (e) {
    crumb('JS ERROR ' + (e.message || '') + ' @' + (e.filename || '') + ':' + (e.lineno || ''));
    send('error', { message: String(e.message), at: (e.filename || '') + ':' + (e.lineno || '') });
  });
  window.addEventListener('unhandledrejection', function (e) {
    var m = e.reason && (e.reason.message || String(e.reason));
    crumb('REJECTED ' + m);
    send('error', { message: 'unhandled: ' + m });
  });
  var err = console.error;
  console.error = function () {
    var m = Array.prototype.join.call(arguments, ' ');
    crumb('ERR ' + m);
    if (/SCRIPT ERROR|Failed loading|out of memory|OOM|Aborted/i.test(m)) send('error', { message: m.substr(0, 2000) });
    return err.apply(console, arguments);
  };
  window.addEventListener('load', function () {
    var cv = document.getElementById('canvas');
    if (cv) cv.addEventListener('webglcontextlost', function () { crumb('WEBGL CONTEXT LOST'); send('error', { message: 'webgl context lost' }); });
  });
})();
