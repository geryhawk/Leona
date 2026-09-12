(function () {
  var KEY = "leona-lang";
  var root = document.documentElement;

  function pick() {
    var q = new URLSearchParams(location.search).get("lang");
    if (q === "fr" || q === "en") return q;
    try { var s = localStorage.getItem(KEY); if (s === "fr" || s === "en") return s; } catch (e) {}
    var nav = (navigator.language || "en").toLowerCase();
    return nav.indexOf("fr") === 0 ? "fr" : "en";
  }

  function apply(lang) {
    root.setAttribute("data-lang", lang);
    root.setAttribute("lang", lang);
    var buttons = document.querySelectorAll(".lang button");
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].classList.toggle("on", buttons[i].getAttribute("data-set") === lang);
    }
    var title = document.querySelector('title[data-' + lang + ']');
    if (title) document.title = title.getAttribute("data-" + lang);
    try { localStorage.setItem(KEY, lang); } catch (e) {}
  }

  apply(pick());

  document.addEventListener("click", function (ev) {
    var b = ev.target.closest && ev.target.closest(".lang button");
    if (!b) return;
    apply(b.getAttribute("data-set"));
  });
})();
