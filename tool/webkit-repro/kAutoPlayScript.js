
(function () {
  // CHỐNG CHẠY LẶP. Script này được tiêm nhiều lần (onLoadStop, và nhịp tự lành
  // cầu nối), mà mỗi lần chạy là tạo thêm một setInterval ép phát. Interval sinh
  // sau thấy video đang tạm dừng là ép phát lại -> người dùng bấm pause xong một
  // lúc phim tự chạy. Trang mới (đổi tập) có window mới nên cờ tự reset.
  if (window.__vfAutoPlay) return;
  window.__vfAutoPlay = 1;
  function biggest(sel) {
    var els, best = null, area = 0;
    try { els = document.querySelectorAll(sel); } catch (e) { return null; }
    for (var i = 0; i < els.length; i++) {
      var r = els[i].getBoundingClientRect();
      var a = r.width * r.height;
      if (a > area && els[i].offsetParent !== null) { area = a; best = els[i]; }
    }
    return best;
  }
  function fireClick(el) {
    if (!el) return;
    try {
      var r = el.getBoundingClientRect();
      var x = r.left + r.width / 2, y = r.top + r.height / 2;
      ['pointerover','mouseover','pointerdown','mousedown','pointerup','mouseup','click'].forEach(function (t) {
        var ev;
        try { ev = new MouseEvent(t, { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y, button: 0 }); }
        catch (e) { ev = document.createEvent('MouseEvents'); ev.initEvent(t, true, true); }
        el.dispatchEvent(ev);
      });
    } catch (e) {}
  }
  function playing() {
    try { var v = document.querySelector('video'); return v && !v.paused && !v.ended && v.currentTime > 0; }
    catch (e) { return false; }
  }
  function tryPlay() {
    if (playing()) return;
    // 1) HTML5 <video> trực tiếp
    try {
      var v = document.querySelector('video');
      if (v) { var p = v.play(); if (p && p.catch) p.catch(function () { try { v.muted = true; v.play(); } catch (e) {} }); }
    } catch (e) {}
    // 2) JWPlayer API
    try { if (typeof window.jwplayer === 'function') { var jp = window.jwplayer(); if (jp && jp.play) jp.play(true); } } catch (e) {}
    // 3) video.js API
    try { var vjs = document.querySelector('.video-js'); if (vjs && vjs.player && vjs.player.play) vjs.player.play(); } catch (e) {}
    // 4) Bấm nút play overlay theo class phổ biến
    try {
      var sels = ['.jw-icon-display', '.jw-display-icon-container', '.vjs-big-play-button',
                  '.plyr__control--overlaid', '[class*="play-button"]', '[class*="btn-play"]',
                  '[aria-label*="Play"]', '[title*="Play"]', '[class*="vjs-play"]'];
      for (var i = 0; i < sels.length; i++) { var b = document.querySelector(sels[i]); if (b && b.offsetParent !== null) { fireClick(b); break; } }
    } catch (e) {}
    // 5) Dự phòng: bấm vào GIỮA khung video/player lớn nhất (nhiều player play khi click)
    if (!playing()) {
      var target = biggest('video') || biggest('.jwplayer, #player, .video-js, .plyr, .player, [class*="player"]');
      fireClick(target);
    }
  }
  // Hộp "THÔNG BÁO! Bạn đã dừng lại ở ..." của trang: remote không bấm được,
  // nên tự chọn giúp. Mặc định "Tiếp tục xem"; nếu app yêu cầu xem lại từ đầu
  // (window.__VIEFLIX_RESTART) thì bấm "Xem lại từ đầu".
  function answerResumeDialog() {
    try {
      // Nguồn (nguonc) tự nhớ vị trí -> hiện hộp "Bạn đã dừng lại ở ...".
      // Mặc định bấm "Tiếp tục xem" để XEM TIẾP đúng chỗ nguồn đã lưu.
      // Khớp rộng ('tiếp tục' / 'từ đầu') phòng khi chữ trên nút hơi khác.
      var want = window.__VIEFLIX_RESTART ? 'từ đầu' : 'tiếp tục';
      var els = document.querySelectorAll('button, a, div, span, input[type="button"]');
      for (var i = 0; i < els.length; i++) {
        var el = els[i];
        if (!el || el.offsetParent === null) continue;
        var t = (el.textContent || el.value || '').toString().trim().toLowerCase();
        if (!t || t.length > 30 || el.children.length > 2) continue;
        if (t.indexOf(want) >= 0) { fireClick(el); return true; }
      }
    } catch (e) {}
    return false;
  }

  tryPlay();
  answerResumeDialog();
  var n = 0;
  var t = setInterval(function () {
    // Người dùng chủ động tạm dừng (qua nút của app) -> THÔI ép phát ngay, kể cả
    // khi phim chưa từng chạy. Cờ do cầu nối đặt, xem kPlayerBridgeScript.
    if (window.__vfUserPaused) { clearInterval(t); return; }
    answerResumeDialog();
    // Khi video ĐÃ bắt đầu chạy -> NGỪNG ép phát, để không đè lên lệnh tạm dừng
    // của người dùng (trước đây pause xong bị script tự bật lại sau ~1 giây).
    if (playing()) { clearInterval(t); return; }
    tryPlay();
    // Ghi trạng thái để chẩn đoán khi phim không tự chạy (xem log của app).
    if (n === 3 || n === 12) {
      try {
        var v = document.querySelector('video');
        var st = '';
        try { st = (typeof window.jwplayer === 'function') ? window.jwplayer().getState() : 'nojw'; } catch (e) { st = 'jwerr'; }
        console.log('VIEFLIX_DBG state=' + st + ' hasVideo=' + !!v +
          ' paused=' + (v && v.paused) + ' t=' + (v ? v.currentTime.toFixed(1) : '-') +
          ' rs=' + (v && v.readyState) + ' frames=' + document.querySelectorAll('iframe').length);
      } catch (e) {}
    }
    if (++n > 25) clearInterval(t);
  }, 600);
})();
