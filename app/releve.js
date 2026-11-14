/* AppYa — lecture des relevés bancaires.
   PDF avec texte : pdf.js (fichiers pdf.min.js et pdf.worker.min.js, dans l'application, hors ligne).
   PDF scanné ou photo : reconnaissance de caractères (OCR) tesseract.js, en français, téléchargée à la demande
   (connexion nécessaire la première fois seulement). Tout se passe dans l'appareil : le relevé n'est envoyé nulle part.
   Résultat : {du, au, solde, lignes: [{date, valeur, libelle, montant, sens: 'debit'|'credit'}], source}. */
(function () {
  'use strict';
  let pdfjsP = null, tessP = null;
  const TESSERACT = 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';
  function script(src) {
    return new Promise((res, rej) => { const s = document.createElement('script'); s.src = src; s.onload = res;
      s.onerror = () => rej(new Error('Module introuvable : ' + src)); document.head.appendChild(s); });
  }
  function pdfjs() {
    if (!pdfjsP) pdfjsP = script('pdf.min.js').then(() => { const L = window.pdfjsLib; L.GlobalWorkerOptions.workerSrc = 'pdf.worker.min.js'; return L; });
    return pdfjsP;
  }
  function tesseract() {
    if (!tessP) tessP = script(TESSERACT).then(() => window.Tesseract)
      .catch(() => { tessP = null; throw new Error("La lecture d'images (OCR) se télécharge la première fois : connectez-vous à internet puis réessayez."); });
    return tessP;
  }

  /* ---------- mots positionnés {t, x, y (centre vertical, vers le bas), w, h, p} ---------- */
  async function lirePDF(buf, progres) {
    const L = await pdfjs();
    const doc = await L.getDocument({data: buf}).promise, mots = [], pages = [];
    for (let p = 1; p <= doc.numPages; p++) {
      const page = await doc.getPage(p), vp = page.getViewport({scale: 1}), tc = await page.getTextContent();
      for (const it of tc.items) {
        const t = String(it.str || '').replace(/\s+/g, ' ').trim(); if (!t) continue;
        const h = Math.abs(it.transform[3]) || it.height || 8;
        mots.push({t, x: it.transform[4], y: vp.height - it.transform[5] - h / 2, w: it.width || t.length * h * .5, h, p});
      }
      pages.push(page);
    }
    if (mots.length >= 15) return {mots, source: 'pdf'};
    // PDF scanné (sans texte) : chaque page est dessinée puis lue par OCR
    const images = [];
    for (const page of pages) {
      const vp = page.getViewport({scale: 2.5}), c = document.createElement('canvas'); c.width = vp.width; c.height = vp.height;
      await page.render({canvasContext: c.getContext('2d'), viewport: vp}).promise; images.push(c);
    }
    return {mots: await ocr(images, progres), source: 'ocr'};
  }
  async function ocr(images, progres) {
    const T = await tesseract();
    const w = await T.createWorker('fra', 1, {logger: m => { if (progres && m.status === 'recognizing text') progres(m.progress); }});
    const mots = [];
    try {
      for (let i = 0; i < images.length; i++) {
        const {data} = await w.recognize(images[i]);
        for (const wd of data.words || []) {
          const t = String(wd.text || '').trim(); if (!t) continue;
          const b = wd.bbox; mots.push({t, x: b.x0, y: (b.y0 + b.y1) / 2, w: b.x1 - b.x0, h: b.y1 - b.y0, p: i + 1});
        }
      }
    } finally { await w.terminate(); }
    return mots;
  }

  /* ---------- analyse ---------- */
  const sansAccents = s => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  const RE_DATE = /^(\d{2})[\/.-](\d{2})[\/.-](\d{2}|\d{4})$/;
  const isoDe = s => { const m = RE_DATE.exec(s); if (!m) return ''; const y = m[3].length === 2 ? '20' + m[3] : m[3]; return `${y}-${m[2]}-${m[1]}`; };
  const RE_NOMBRE = /^-?\d{1,3}([\s  .]\d{3})*(,\d{1,2})?$|^-?\d+(,\d{1,2})?$/;
  const nombre = s => Number(String(s).replace(/[\s  .]/g, '').replace(',', '.'));
  const mediane = a => { const b = [...a].sort((x, y) => x - y); return b.length ? b[Math.floor(b.length / 2)] : 0; };

  function enLignes(mots) {
    const out = [];
    const tri = [...mots].sort((a, b) => a.p - b.p || a.y - b.y || a.x - b.x);
    for (const m of tri) {
      const l = out[out.length - 1];
      if (l && l.p === m.p && Math.abs(l.y - m.y) <= Math.max(2, .55 * Math.min(l.h, m.h))) { l.mots.push(m); l.h = Math.max(l.h, m.h); }
      else out.push({p: m.p, y: m.y, h: m.h, mots: [m]});
    }
    for (const l of out) { l.mots.sort((a, b) => a.x - b.x); l.texte = l.mots.map(m => m.t).join(' '); }
    return out;
  }
  /* un montant peut être découpé en plusieurs mots (« 300 » « 000 » en OCR) : on recolle les groupes de 3 chiffres proches */
  function montantsDe(mots, h) {
    const res = [];
    for (const m of mots) {
      const t = m.t.replace(/[^\d\s  .,-]/g, '').trim(); if (!t || !RE_NOMBRE.test(t)) { res.push(null); continue; }
      const prec = res[res.length - 1];
      if (prec && /^\d{3}(,\d{1,2})?$/.test(t) && m.x - (prec.x + prec.w) < 1.2 * h) { prec.t += ' ' + t; prec.w = m.x + m.w - prec.x; continue; }
      res.push({t, x: m.x, w: m.w});
    }
    return res.filter(Boolean).map(a => ({v: nombre(a.t), c: a.x + a.w / 2, x: a.x}));
  }

  function analyser(mots) {
    const lignes = enLignes(mots), h = mediane(mots.map(m => m.h)) || 8;
    const tout = lignes.map(l => l.texte).join('\n');
    let du = '', au = '';
    const per = /du\s+(\d{2}[\/.-]\d{2}[\/.-]\d{2,4})\s+au\s+(\d{2}[\/.-]\d{2}[\/.-]\d{2,4})/i.exec(sansAccents(tout));
    if (per) { du = isoDe(per[1]); au = isoDe(per[2]); }
    // colonnes : en-tête « Débit … Crédit » (répété sur chaque page)
    const cols = {};
    for (const l of lignes) {
      const deb = l.mots.find(m => /^debit/.test(sansAccents(m.t))), cre = l.mots.find(m => /^credit/.test(sansAccents(m.t)));
      if (deb && cre) {
        const val = l.mots.find(m => /valeur/.test(sansAccents(m.t)));
        cols[l.p] = {deb: deb.x + deb.w / 2, cre: cre.x + cre.w / 2, finLib: val ? val.x + val.w + h : Math.min(deb.x, cre.x) - 2 * h};
      }
    }
    const colsDe = p => cols[p] || cols[Object.keys(cols).find(k => +k <= p)] || Object.values(cols)[0] || null;
    let solde = null; const ops = [];
    for (let i = 0; i < lignes.length; i++) {
      const l = lignes[i], ts = l.mots.map(m => m.t), d0 = isoDe(ts[0] || '');
      const st = sansAccents(l.texte);
      if (/solde/.test(st) && !d0) { const ms = montantsDe(l.mots, h); if (ms.length) solde = ms[ms.length - 1].v; continue; }
      if (!d0) {
        // suite du libellé de la ligne précédente (texte seul, dans la colonne du libellé)
        const prev = ops[ops.length - 1], c = colsDe(l.p);
        if (prev && prev.p === l.p && l.y - prev.y < 2.2 * h && c && l.mots.every(m => m.x + m.w <= c.finLib) && !/page|solde|banque|swift/i.test(l.texte)) prev.libelle += ' ' + l.texte;
        continue;
      }
      const c = colsDe(l.p);
      let reste = l.mots.slice(1), valeur = '';
      const iv = reste.findIndex(m => RE_DATE.test(m.t));
      if (iv >= 0) { valeur = isoDe(reste[iv].t); }
      const limite = c ? c.finLib : (iv >= 0 ? reste[iv].x + reste[iv].w : Infinity);
      const libMots = reste.filter((m, k) => k !== iv && (m.x + m.w / 2) < limite);
      const numMots = reste.filter((m, k) => k !== iv && (m.x + m.w / 2) >= limite);
      const ms = montantsDe(numMots, h).filter(a => a.v > 0);
      if (!ms.length) continue;
      const a = ms[ms.length - 1];
      let sens;
      if (c) sens = Math.abs(a.c - c.deb) <= Math.abs(a.c - c.cre) ? 'debit' : 'credit';
      else sens = /(recu|versement|credit|vir\.? ?recu)/i.test(sansAccents(libMots.map(m => m.t).join(' '))) ? 'credit' : 'debit';
      ops.push({date: d0, valeur, libelle: libMots.map(m => m.t).join(' ').replace(/\s+/g, ' ').replace(/^[^\p{L}\p{N}]+/u, '').trim(), montant: Math.round(a.v), sens, p: l.p, y: l.y});
    }
    ops.forEach(o => { delete o.p; delete o.y; });
    if (!du && ops.length) du = ops.map(o => o.date).sort()[0];
    if (!au && ops.length) au = ops.map(o => o.date).sort().pop();
    return {du, au, solde, lignes: ops, colonnes: Object.keys(cols).length > 0};
  }

  async function lire(fichier, progres) {
    const buf = await fichier.arrayBuffer(), nom = String(fichier.name || '').toLowerCase();
    let r;
    if (fichier.type === 'application/pdf' || nom.endsWith('.pdf')) r = await lirePDF(new Uint8Array(buf), progres);
    else if (/^image\//.test(fichier.type) || /\.(jpe?g|png|webp|bmp|tiff?)$/.test(nom)) r = {mots: await ocr([fichier], progres), source: 'ocr'};
    else throw new Error('Format non pris en charge : choisissez un PDF ou une photo (JPG, PNG).');
    const a = analyser(r.mots);
    a.source = r.source; a.texte = enLignes(r.mots).map(l => l.texte).join('\n');
    return a;
  }

  window.AppYaReleve = {lire, analyser, enLignes};
})();
