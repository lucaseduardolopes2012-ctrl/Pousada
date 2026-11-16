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
  const STATUS = { solicitada: "Pedido novo", confirmada: "Confirmada", hospedado: "Hospedado", finalizada: "Finalizada", cancelada: "Cancelada", no_show: "Não veio" };
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
  window.PG = { sb, esc, brl, hoje, addDias, noites, dm, dmy, STATUS, ORIGEM, errText, aplicaCor, ding, toast, COMODIDADES, PAGAMENTOS, CORES, ACESSO };
})();
