/* GFP, LLC — interactions */
(function () {
  'use strict';

  /* ---- topbar + scroll progress ---- */
  const topbar = document.getElementById('topbar');
  const bar = document.getElementById('scrollbar');
  function onScroll() {
    const y = window.scrollY || 0;
    topbar.classList.toggle('scrolled', y > 24);
    const h = document.documentElement.scrollHeight - window.innerHeight;
    bar.style.width = (h > 0 ? (y / h) * 100 : 0) + '%';
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---- scroll-spy on nav ---- */
  const links = Array.from(document.querySelectorAll('#navlinks a'));
  const map = new Map();
  links.forEach((a) => {
    const id = a.getAttribute('href').slice(1);
    const sec = document.getElementById(id);
    if (sec) map.set(sec, a);
  });
  const spy = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) {
        links.forEach((l) => l.classList.remove('active'));
        const a = map.get(e.target);
        if (a) a.classList.add('active');
      }
    });
  }, { rootMargin: '-45% 0px -50% 0px', threshold: 0 });
  map.forEach((_, sec) => spy.observe(sec));

  /* ---- reveal on scroll ---- */
  const revObs = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) { e.target.classList.add('in'); revObs.unobserve(e.target); }
    });
  }, { rootMargin: '0px 0px -12% 0px', threshold: 0.08 });
  document.querySelectorAll('.reveal, [data-stagger]').forEach((el) => revObs.observe(el));

  /* ---- process step fill ---- */
  const stepObs = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); stepObs.unobserve(e.target); } });
  }, { threshold: 0.4 });
  document.querySelectorAll('.step').forEach((el) => stepObs.observe(el));

  /* ---- animated counters ---- */
  function animateCount(el) {
    const target = parseFloat(el.getAttribute('data-count'));
    const dec = parseInt(el.getAttribute('data-dec') || '0', 10);
    const dur = 1500;
    const start = performance.now();
    function tick(now) {
      const p = Math.min((now - start) / dur, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      const val = target * eased;
      el.textContent = dec ? val.toFixed(dec) : Math.round(val).toLocaleString();
      if (p < 1) requestAnimationFrame(tick);
      else el.textContent = dec ? target.toFixed(dec) : Math.round(target).toLocaleString();
    }
    requestAnimationFrame(tick);
  }
  const countObs = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) { animateCount(e.target); countObs.unobserve(e.target); } });
  }, { threshold: 0.6 });
  document.querySelectorAll('[data-count]').forEach((el) => countObs.observe(el));

  /* ---- form: float labels, validation, success ---- */
  const form = document.getElementById('cform');
  if (form) {
    const fields = Array.from(form.querySelectorAll('.field'));
    function syncFilled(field) {
      const ctrl = field.querySelector('input, textarea, select');
      if (!ctrl) return;
      field.classList.toggle('filled', !!ctrl.value);
    }
    fields.forEach((f) => {
      const ctrl = f.querySelector('input, textarea, select');
      if (!ctrl) return;
      ctrl.addEventListener('input', () => { syncFilled(f); f.classList.remove('err'); });
      ctrl.addEventListener('change', () => syncFilled(f));
      ctrl.addEventListener('blur', () => syncFilled(f));
    });

    form.addEventListener('submit', (ev) => {
      ev.preventDefault();
      let ok = true;
      const checks = [
        ['name', (v) => v.trim().length > 1],
        ['email', (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)],
        ['type', (v) => v.trim().length > 0],
      ];
      checks.forEach(([name, test]) => {
        const ctrl = form.querySelector('[name="' + name + '"]');
        const field = ctrl.closest('.field');
        if (!test(ctrl.value || '')) { field.classList.add('err'); ok = false; }
        else field.classList.remove('err');
      });
      if (!ok) {
        const firstErr = form.querySelector('.field.err input, .field.err select');
        if (firstErr) firstErr.focus();
        return;
      }
      form.style.display = 'none';
      const ok2 = document.getElementById('formSuccess');
      ok2.classList.add('show');
    });
  }

  /* ---- mobile menu toggle ---- */
  const menuBtn = document.getElementById('menuBtn');
  const panel = document.getElementById('mobilePanel');
  if (menuBtn && panel) {
    const setOpen = (open) => {
      panel.classList.toggle('open', open);
      menuBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
      document.body.style.overflow = open ? 'hidden' : '';
    };
    menuBtn.addEventListener('click', () => {
      setOpen(menuBtn.getAttribute('aria-expanded') !== 'true');
    });
    panel.querySelectorAll('a').forEach((a) => a.addEventListener('click', () => setOpen(false)));
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') setOpen(false); });
    window.addEventListener('resize', () => { if (window.innerWidth > 1000) setOpen(false); });
  }
})();
