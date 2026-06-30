// Sticky side-nav scroll-spy + gentle scroll-reveal for the About page.
(function () {
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var sections = Array.prototype.slice.call(document.querySelectorAll(".section[id]"));
  var links = {};
  document.querySelectorAll(".rail a[href^='#']").forEach(function (a) {
    links[a.getAttribute("href").slice(1)] = a;
  });

  // Highlight the rail link for whichever section is currently most in view.
  if ("IntersectionObserver" in window) {
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        var id = e.target.id;
        Object.keys(links).forEach(function (k) {
          var on = k === id;
          links[k].classList.toggle("active", on);
          if (on) links[k].setAttribute("aria-current", "true");
          else links[k].removeAttribute("aria-current");
        });
      });
    }, { rootMargin: "-30% 0px -60% 0px", threshold: 0 });
    sections.forEach(function (s) { spy.observe(s); });
  }

  // Build staggered reveal targets per section: top-level children, with grids/lists
  // expanded into their own items so chips, stats and timeline entries cascade individually.
  function collectReveal(section) {
    var out = [];
    Array.prototype.forEach.call(section.children, function (ch) {
      if (ch.matches && ch.matches(".statgrid, .skills, .tags, .tl")) {
        var kids = Array.prototype.slice.call(ch.children);
        if (kids.length) { out.push.apply(out, kids); return; }
      }
      out.push(ch);
    });
    return out;
  }
  var targets = {};
  sections.forEach(function (s) {
    var items = collectReveal(s);
    items.forEach(function (el, i) {
      el.setAttribute("data-rv", "");
      el.style.setProperty("--d", Math.min(i * 60, 460) + "ms");
    });
    targets[s.id] = items;
  });
  function show(s) {
    s.classList.add("shown");
    (targets[s.id] || []).forEach(function (el) { el.classList.add("in"); });
  }
  function revealAll() {
    sections.forEach(show);
    document.body.classList.add("hero-in");
    document.body.classList.add("reveal-done");
  }

  // Reduced-motion or no IntersectionObserver: show everything immediately, no animation.
  if (reduce || !("IntersectionObserver" in window)) { revealAll(); return; }

  // Cascade each section's contents in as it scrolls into view.
  document.body.classList.add("reveal-on");
  // Trigger the hero entrance on the next frames so the transition runs from its start state.
  requestAnimationFrame(function () { requestAnimationFrame(function () { document.body.classList.add("hero-in"); }); });
  var reveal = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) { show(e.target); reveal.unobserve(e.target); }
    });
  }, { rootMargin: "0px 0px -12% 0px", threshold: 0.08 });
  sections.forEach(function (s) { reveal.observe(s); });

  // Always reveal whatever is on screen at load, so the top of the page is never blank.
  function revealInView() {
    var vh = window.innerHeight || document.documentElement.clientHeight;
    sections.forEach(function (s) {
      if (s.getBoundingClientRect().top < vh * 0.92) show(s);
    });
  }
  revealInView();
  window.addEventListener("load", revealInView);

  // Fail-safe: if anything is still hidden after a moment, force it visible — content must never stay invisible.
  setTimeout(revealAll, 1800);
})();

// Collapsible embedded tracker.
(function () {
  var btn = document.querySelector(".embed-toggle");
  if (!btn) return;
  var wrap = document.getElementById(btn.getAttribute("aria-controls"));
  if (!wrap) return;
  btn.addEventListener("click", function () {
    var collapsed = wrap.classList.toggle("collapsed");
    btn.setAttribute("aria-expanded", String(!collapsed));
    btn.textContent = collapsed ? "Show live tracker" : "Hide live tracker";
  });
})();

// Skeleton loaders for embedded iframes (live tracker + PDF viewers).
// Each iframe is wrapped and overlaid with a shimmering placeholder that fades
// out once the frame fires its load event (with an 8s fail-safe so it never sticks).
(function () {
  function markup(label) {
    return '<div class="skbar t"></div><div class="skbar w90"></div>' +
           '<div class="skbar w70"></div><div class="skbar w80"></div>' +
           '<div class="skbar w50"></div><div class="sk-spacer"></div>' +
           '<div class="sk-foot"><span class="sk-dot"></span>' + label + '</div>';
  }
  function attach(iframe, kind, label) {
    if (!iframe) return;
    var wrap = document.createElement("div");
    wrap.className = "frame-wrap k-" + kind;
    iframe.parentNode.insertBefore(wrap, iframe);
    wrap.appendChild(iframe);                 // moving the iframe re-triggers its load
    var skel = document.createElement("div");
    skel.className = "frame-skel";
    skel.setAttribute("aria-hidden", "true");
    skel.innerHTML = markup(label);
    wrap.appendChild(skel);
    var done = false;
    function finish() { if (done) return; done = true; wrap.classList.add("loaded"); }
    iframe.addEventListener("load", function () { setTimeout(finish, 200); });
    setTimeout(finish, 8000);
  }
  attach(document.querySelector(".embed-frame"), "embed", "Loading live tracker\u2026");
  document.querySelectorAll(".deck-frame").forEach(function (f) { attach(f, "deck", "Loading slides\u2026"); });
  attach(document.querySelector(".doc-frame"), "doc", "Loading document\u2026");
})();

