/* Gestão de pousada: código compartilhado */
(function () {
  const cfg = window.PG_CONFIG;
  const sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseKey, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false } });
  const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const brl = v => "R$ " + Number(v || 0).toFixed(2).replace(".", ",");
  const pad = n => String(n).padStart(2, "0");
  const hoje = () => new Intl.DateTimeFormat("sv-SE", { timeZone: "America/Sao_Paulo" }).format(new Date()); // AAAA-MM-DD
  const toUTC = s => { const [y, m, d] = s.split("-").map(Number); return Date.UTC(y, m - 1, d); };
  const addDias = (s, n) => { const t = new Date(toUTC(s) + n * 86400000); return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`; };
  const noites = (a, b) => Math.round((toUTC(b) - toUTC(a)) / 86400000);
  const dm = s => s ? `${s.slice(8, 10)}/${s.slice(5, 7)}` : "";
  const dmy = s => s ? `${s.slice(8, 10)}/${s.slice(5, 7)}/${s.slice(0, 4)}` : "";
  const STATUS = { aguardando_pagamento: "Aguardando pagamento", solicitada: "Pedido novo", confirmada: "Confirmada", hospedado: "Hospedado", finalizada: "Finalizada", cancelada: "Cancelada", no_show: "Não veio" };
  const ORIGEM = { site: "Site", balcao: "Balcão", telefone: "Telefone", whatsapp: "WhatsApp", booking: "Booking", outro: "Outro" };

  function errText(e) {
    const m = (e && (e.message || e.error_description || e)) + "";
    if (/Invalid login credentials/i.test(m)) return "Email ou senha incorretos.";
    if (/already registered|already been registered/i.test(m)) return "Já existe uma conta com esse email. Entre com a sua senha.";
    if (/Password should be at least|weak password/i.test(m)) return "A senha precisa ter pelo menos 8 caracteres.";
    if (/rate limit|too many/i.test(m)) return "Muitas tentativas seguidas. Espere um minuto.";
    if (/exclusion|23P01|conflicting key/i.test(m)) return "Esse quarto já tem uma reserva confirmada nessas datas.";
    if (/violates check constraint/i.test(m)) return "Algum campo está com valor inválido. Confira os dados.";
    if (/permission denied|row-level security/i.test(m)) return "Você não tem permissão para fazer isso.";
    if (/Failed to fetch|NetworkError/i.test(m)) return "Sem conexão com o servidor. Confira a internet.";
    return m.replace(/^.*?ERROR:\s*/, "");
  }

  // cor da pousada: calcula texto claro ou escuro por cima
  function aplicaCor(hex) {
    if (!/^#[0-9a-fA-F]{6}$/.test(hex || "")) return;
    const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));
    const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    document.documentElement.style.setProperty("--cor", hex);
    document.documentElement.style.setProperty("--cor-ink", lum > 0.6 ? "#1d2a26" : "#ffffff");
  }

  let ctx = null;
  function ding() {
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      const t0 = ctx.currentTime;
      [784, 1046, 784].forEach((f, i) => {
        const o = ctx.createOscillator(), g = ctx.createGain(); o.type = "sine"; o.frequency.value = f;
        g.gain.setValueAtTime(0.0001, t0 + i * 0.26); g.gain.exponentialRampToValueAtTime(0.25, t0 + i * 0.26 + 0.02); g.gain.exponentialRampToValueAtTime(0.0001, t0 + i * 0.26 + 0.24);
        o.connect(g).connect(ctx.destination); o.start(t0 + i * 0.26); o.stop(t0 + i * 0.26 + 0.25);
      });
    } catch (e) {}
    try { navigator.vibrate && navigator.vibrate([150, 80, 150]); } catch (e) {}
  }
  document.addEventListener("pointerdown", () => { try { ctx = ctx || new (window.AudioContext || window.webkitAudioContext)(); ctx.resume(); } catch (e) {} }, { once: true });
  function toast(text) { let t = document.getElementById("toast"); if (!t) { t = document.createElement("div"); t.id = "toast"; t.className = "recado"; t.setAttribute("role", "status"); document.body.appendChild(t); } t.textContent = text; t.hidden = false; clearTimeout(toast.h); toast.h = setTimeout(() => (t.hidden = true), 4500); }

  const COMODIDADES = ["Café da manhã incluso", "Wi-Fi", "Estacionamento", "Ar-condicionado", "Ventilador", "Roupa de cama e banho", "Cozinha para hóspedes", "Churrasqueira", "Piscina", "Vista para o mar", "Passeios de barco", "Traslado de barco", "Aceita pets", "Acessível para cadeira de rodas"];
  const PAGAMENTOS = ["Pix", "Cartão de crédito", "Cartão de débito", "Dinheiro", "Transferência"];
  const CORES = [["Maré", "#0e6e6a"], ["Mata", "#2f6b3a"], ["Céu", "#2c5d9e"], ["Cara-roxa", "#8e2f5a"], ["Pôr do sol", "#b4532a"], ["Areia", "#8a6a33"], ["Noite", "#28324a"]];
  const ACESSO = { estrada: "De carro ou ônibus", barco: "Só de barco", ambos: "Pela estrada ou de barco" };
  /* ---------- Pix: chave do dono -> "copia e cola" e QR code (BR Code estático, sem intermediário) ---------- */
  // @pix-inicio
  const pixAscii = (t, n) => String(t || "").normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^A-Za-z0-9 ]/g, " ").replace(/\s+/g, " ").trim().toUpperCase().slice(0, n);
  const pixTlv = (id, v) => id + String(v.length).padStart(2, "0") + v;
  const pixCrc = t => { let c = 0xFFFF; for (let i = 0; i < t.length; i++) { c ^= t.charCodeAt(i) << 8; for (let k = 0; k < 8; k++) c = (c & 0x8000) ? ((c << 1) ^ 0x1021) & 0xFFFF : (c << 1) & 0xFFFF; } return c.toString(16).toUpperCase().padStart(4, "0"); };
  function pixPayload({ chave, valor, nome, cidade, txid }) {
    const conta = pixTlv("00", "br.gov.bcb.pix") + pixTlv("01", chave);
    const v = Number(valor) > 0 ? Number(valor).toFixed(2) : "";
    const ref = String(txid || "").replace(/[^A-Za-z0-9]/g, "").slice(0, 25) || "***";
    const corpo = pixTlv("00", "01") + pixTlv("01", "11") + pixTlv("26", conta) + pixTlv("52", "0000") + pixTlv("53", "986") + (v ? pixTlv("54", v) : "")
      + pixTlv("58", "BR") + pixTlv("59", pixAscii(nome, 25) || "PAGAMENTO") + pixTlv("60", pixAscii(cidade, 15) || "BRASIL") + pixTlv("62", pixTlv("05", ref)) + "6304";
    return corpo + pixCrc(corpo);
  }
  const cpfOk = d => { if (/^(\d)\1+$/.test(d)) return false; for (const t of [9, 10]) { let s = 0; for (let i = 0; i < t; i++) s += Number(d[i]) * (t + 1 - i); if ((s * 10) % 11 % 10 !== Number(d[t])) return false; } return true; };
  const cnpjOk = d => { if (/^(\d)\1+$/.test(d)) return false; for (const t of [12, 13]) { let s = 0, p = t - 7; for (let i = 0; i < t; i++) { s += Number(d[i]) * p--; if (p < 2) p = 9; } if ((s % 11 < 2 ? 0 : 11 - s % 11) !== Number(d[t])) return false; } return true; };
  const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
  // tipos: cpf_cnpj, celular, email, aleatoria. Devolve a chave no formato que o banco exige, ou o erro em português.
  function pixChave(tipo, bruto) {
    const t = String(bruto || "").trim(); const d = t.replace(/\D/g, "");
    if (tipo === "cpf_cnpj") { if (d.length === 11 && cpfOk(d)) return { ok: true, chave: d }; if (d.length === 14 && cnpjOk(d)) return { ok: true, chave: d }; return { ok: false, erro: "CPF ou CNPJ inválido. Confira os números." }; }
    if (tipo === "celular") { const n = d.length >= 12 && d.startsWith("55") ? d.slice(2) : d; if (n.length === 10 || n.length === 11) return { ok: true, chave: "+55" + n }; return { ok: false, erro: "Celular inválido. Coloque o DDD e o número, por exemplo (41) 99999-0000." }; }
    if (tipo === "email") { const e = t.toLowerCase(); if (e.length <= 77 && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)) return { ok: true, chave: e }; return { ok: false, erro: "E-mail inválido." }; }
    if (tipo === "aleatoria") { const u = t.toLowerCase(); if (UUID.test(u)) return { ok: true, chave: u }; return { ok: false, erro: "Chave aleatória inválida. Copie ela inteira do app do banco (32 letras e números, com traços)." }; }
    return { ok: false, erro: "Escolha o tipo da chave." };
  }
  const pixTipo = c => { const t = String(c || ""); return t.includes("@") ? "email" : t.startsWith("+") ? "celular" : UUID.test(t) ? "aleatoria" : "cpf_cnpj"; };
  // @pix-fim

  // @tema-inicio
  // Tema por pousada: 3 cores (principal, apoio, escuro) e um desenho (motivo). O resto sai dessas cores no CSS.
  // Vazio = o padrão do sistema (azul-marinho e laranja). Quem usa: site.html, reserva.html e painel.html.
  const HEX = /^#[0-9a-fA-F]{6}$/;
  const MOTIVOS = { nenhum: "Sem desenho", guara: "Guarás", pinheiro: "Pinheiros" };
  // modelo = o desenho da página inteira (não só as cores): "classico" ou um dos que ficam na pasta modelos/
  const MODELOS = { classico: "Clássico (cabeçalho, bilhete de datas e cartões)", horadourada: "Hora dourada (céu que escurece, sol que desce, quartos em lista)" };
  const TEMA_PADRAO = { principal: "#c8302b", apoio: "#5a3b2c", escuro: "#1d1512", motivo: "nenhum", modelo: "classico" };
  const luz = h => { const [r, g, b] = [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16) / 255).map(v => v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4)); return .2126 * r + .7152 * g + .0722 * b; };
  // contraste entre duas cores (1 a 21). Letra branca sobre a cor principal precisa de pelo menos 3 para ler bem.
  const contraste = (a, b) => { const x = luz(a), y = luz(b); return (Math.max(x, y) + .05) / (Math.min(x, y) + .05); };
  function temaValido(t) {
    if (!t || typeof t !== "object" || !HEX.test(t.principal || "")) return null;
    return { principal: t.principal.toLowerCase(), apoio: HEX.test(t.apoio || "") ? t.apoio.toLowerCase() : TEMA_PADRAO.apoio, escuro: HEX.test(t.escuro || "") ? t.escuro.toLowerCase() : TEMA_PADRAO.escuro, motivo: MOTIVOS[t.motivo] ? t.motivo : "nenhum", modelo: MODELOS[t.modelo] ? t.modelo : "classico" };
  }
  // põe o tema na página; devolve o tema aplicado, ou null quando fica o padrão
  function aplicaTema(t) {
    const r = document.documentElement, x = temaValido(t), meta = document.querySelector('meta[name="theme-color"]');
    if (!meta.dataset.padrao) meta.dataset.padrao = meta.content;
    if (!x) { delete r.dataset.tema; delete r.dataset.motivo; delete r.dataset.modelo; ["--g-vermelho", "--g-marrom", "--g-preto"].forEach(v => r.style.removeProperty(v)); meta.content = meta.dataset.padrao; return null; }
    r.dataset.tema = "pousada"; r.dataset.motivo = x.motivo; r.dataset.modelo = x.modelo;
    r.style.setProperty("--g-vermelho", x.principal); r.style.setProperty("--g-marrom", x.apoio); r.style.setProperty("--g-preto", x.escuro);
    meta.content = x.principal; return x;
  }
  // @tema-fim

  window.PG = { aplicaTema, temaValido, contraste, MOTIVOS, MODELOS, TEMA_PADRAO, pixPayload, pixChave, pixTipo, sb, esc, brl, hoje, addDias, noites, dm, dmy, STATUS, ORIGEM, errText, aplicaCor, ding, toast, COMODIDADES, PAGAMENTOS, CORES, ACESSO };
})();
