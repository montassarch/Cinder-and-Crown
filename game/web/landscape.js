// Plays the game sideways on a phone held upright (or with rotation lock on): when the browser window is taller than
// it is wide, the game canvas is turned 90 degrees to fill the screen in landscape, and every size and touch position
// Godot reads is turned with it. Held sideways for real, nothing changes. Safari on the iPhone cannot lock the
// orientation, so this is the only way to always get the full landscape screen.
// Injected into the web export's <head> by tools/web/inject_head.py (it must not contain double quotes).
(function () {
  function getter(name) {
    for (let o = window; o; o = Object.getPrototypeOf(o)) {
      const d = Object.getOwnPropertyDescriptor(o, name);
      if (d && d.get) return d.get;
    }
    return null;
  }
  const realW = getter('innerWidth');
  const realH = getter('innerHeight');
  if (!realW || !realH) return;
  const vw = function () { return realW.call(window); };
  const vh = function () { return realH.call(window); };
  const turned = function () { return vh() > vw(); };
  window.cinderTurned = turned;

  // the window Godot sizes itself to is the landscape one
  Object.defineProperty(window, 'innerWidth', { configurable: true, get: function () { return turned() ? vh() : vw(); } });
  Object.defineProperty(window, 'innerHeight', { configurable: true, get: function () { return turned() ? vw() : vh(); } });

  // a touch at screen (x, y) lands on the turned canvas at (y, screenWidth - x)
  function turn(proto) {
    if (!proto) return;
    const gx = Object.getOwnPropertyDescriptor(proto, 'clientX');
    const gy = Object.getOwnPropertyDescriptor(proto, 'clientY');
    if (!gx || !gy || !gx.get || !gy.get) return;
    Object.defineProperty(proto, 'clientX', { configurable: true, get: function () { return turned() ? gy.get.call(this) : gx.get.call(this); } });
    Object.defineProperty(proto, 'clientY', { configurable: true, get: function () { return turned() ? vw() - gx.get.call(this) : gy.get.call(this); } });
  }
  turn(window.Touch && Touch.prototype);
  turn(window.MouseEvent && MouseEvent.prototype);

  const style = document.createElement('style');
  style.textContent = 'html, body { margin: 0; overflow: hidden; background: #000; touch-action: none; overscroll-behavior: none; }' +
    ' body.cinder-turned #canvas { position: fixed; top: 0; left: 0; transform-origin: top left; transform: rotate(90deg) translateY(-100%); }';
  document.head.appendChild(style);

  function update() { document.body.classList.toggle('cinder-turned', turned()); }
  function hook() {
    const canvas = document.getElementById('canvas');
    if (canvas) {
      const real = canvas.getBoundingClientRect.bind(canvas);
      // the canvas' own (unturned) box: Godot scales touch positions by it
      canvas.getBoundingClientRect = function () {
        if (!turned()) return real();
        return new DOMRect(0, 0, canvas.clientWidth, canvas.clientHeight);
      };
    }
    update();
  }
  window.addEventListener('resize', update);
  window.addEventListener('orientationchange', function () { setTimeout(update, 50); });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', hook); else hook();

  // where it is allowed (Android, an installed web app), go truly full screen and lock landscape on the first touch
  function goFull() {
    const el = document.documentElement;
    const req = el.requestFullscreen || el.webkitRequestFullscreen;
    if (req && !document.fullscreenElement) {
      try { const p = req.call(el); if (p && p.catch) p.catch(function () {}); } catch (e) {}
    }
    if (screen.orientation && screen.orientation.lock) { screen.orientation.lock('landscape').catch(function () {}); }
  }
  window.addEventListener('touchend', goFull, { once: true });
})();
