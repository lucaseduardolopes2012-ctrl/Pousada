/* Modelo "Hora dourada": para pousada de frente para a água, onde o pôr do sol é o espetáculo.
   A página é um dia inteiro: começa de manhã, o sol desce enquanto o hóspede rola e, no rodapé, ele se põe no mar atrás dos pinheiros.
   Troca só o desenho (abertura, quartos em lista, rodapé). A busca, a ficha, o Pix e o resto da lógica continuam os do site.html.
   Cores: as 3 da pousada (principal, apoio, escuro), editáveis no painel. */
(function () {
  const M = (window.PG_MODELOS = window.PG_MODELOS || {});
  if (!document.querySelector("link[data-hd-fonte]")) {
    const l = document.createElement("link"); l.rel = "stylesheet"; l.dataset.hdFonte = "1";
    l.href = "https://fonts.googleapis.com/css2?family=Unbounded:wght@300..800&display=swap";
    document.head.appendChild(l);
  }
  const SOL_G = `<circle cx="20" cy="20" r="7.5"/><g stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M20 4v5M20 31v5M4 20h5M31 20h5M8.7 8.7l3.5 3.5M27.8 27.8l3.5 3.5M31.3 8.7l-3.5 3.5M12.2 27.8l-3.5 3.5"/></g>`;
  const SOL_ICONE = `<svg viewBox="0 0 40 40" aria-hidden="true" focusable="false">${SOL_G}</svg>`;
  const PINHEIRO_D = "M30 3 L45 33 Q30 28 15 33 Z M30 19 L50 55 Q30 49 10 55 Z M30 38 L55 80 Q30 73 5 80 Z M27 80 H33 V97 H27 Z";
  // onda que se repete a cada "per" unidades, num desenho de 2400 de largura (o dobro da tela), para correr em loop sem emenda
  const onda = (y, amp, per) => { let d = `M0 ${y}`; for (let x = 0; x < 2400; x += per) d += ` Q${x + per / 4} ${y - amp} ${x + per / 2} ${y} T${x + per} ${y}`; return d; };
  // o nome em duas partes: "Pousada" pequeno (se houver) e o resto grande, com a última palavra em itálico
  function nome(P, esc) {
    const w = String(P.nome).trim().split(/\s+/), art = w.length > 1 && /^(pousada|hotel|chal[eé]|casa|recanto|ref[uú]gio|s[ií]tio)$/i.test(w[0]);
    const pequeno = art ? w[0] : "", resto = art ? w.slice(1) : w; let i = 0;
    const pal = (t, cls = "") => `<span class="hd-pal ${cls}"><span style="--i:${i++}">${esc(t)}</span></span>`;
    const grande = resto.map((t, k) => pal(t, resto.length > 1 && k === resto.length - 1 ? "hd-it" : "")).join(" ");
    return `${pequeno ? `<span class="hd-l1">${pal(pequeno)}</span>` : ""}<span class="hd-l2">${grande}</span>`;
  }

  // "código de barras" feito de pinheiros: alturas e espaços vêm do nome da pousada, então cada uma tem o seu
  function codigoPinhos(nome) {
    let h = 7; for (const ch of String(nome)) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
    let x = 2, out = "";
    for (let i = 0; i < 12; i++) { h = (h * 1103515245 + 12345) >>> 0; const alt = 13 + (h >> 8) % 17, s = alt / 100; out += `<path transform="translate(${x.toFixed(1)} ${(30 - alt).toFixed(1)}) scale(${s.toFixed(3)})" d="${PINHEIRO_D}"/>`; x += 60 * s + 3 + ((h >> 4) % 5); }
    return out;
  }

  // guarás voando (cinco, de tamanhos diferentes); c.GUARA_VOO vem do site.html
  const bando = (c, cls) => `<div class="hd-voo ${cls}" aria-hidden="true">${[1, 2, 3, 4, 5].map(() => `<span>${c.GUARA_VOO}</span>`).join("")}</div>`;

  M.horadourada = {
    topo(c) {
      const { P, CASA, slug, esc, TEMA } = c, marca = TEMA && TEMA.motivo === "pinheiro" ? c.PINHEIRO : SOL_ICONE;
      return `<header class="topo"><div class="dentro"><a class="marca" href="#inicio"><i>${marca}</i><span>${esc(P.nome)}</span></a>
        <nav><a class="l" href="#quartos">Quartos</a><a class="l" href="reserva.html?p=${encodeURIComponent(slug)}">Acompanhar pedido</a>${CASA && CASA.avaliacoes ? '<a class="l" href="#avaliacoes">Avaliações</a>' : ""}${CASA ? '<a class="l" href="#sobre">Sobre a casa</a>' : ""}${c.temSaber ? '<a class="l" href="#saber">Bom saber</a>' : ""}<a class="btn btn--cheio" href="#bilhete">Pedir reserva</a></nav></div></header>`;
    },

    abertura(c) {
      const { P, Q, S, esc, brl, plural, hoje, addDias, lugar, zap, linkZap, precoMin, fotos } = c;
      const txtSelo = `${(lugar || P.cidade || "").toUpperCase()} • ${String(P.nome).toUpperCase()} • `, fs = Math.min(9.2, 270 / (txtSelo.length * .66)).toFixed(2);
      const arco = fotos.length
        ? `<button type="button" class="hd-arco" data-foto="0" aria-label="Ver as fotos da ${esc(P.nome)} em tela cheia"><img src="${esc(fotos[0])}" alt="Foto da ${esc(P.nome)}" fetchpriority="high"></button>`
        : `<div class="hd-arco hd-arco--vazio" aria-hidden="true">${c.PINHAL}</div>`;
      return `<section class="abertura hd-hero">${bando(c, "hd-voo--ceu")}<div class="dentro">
        <div class="hd-txt">
          ${lugar ? `<p class="onde">${c.ICONE_LOCAL}${esc(lugar)}</p>` : ""}
          <h1 class="nome hd-nome" id="nome" aria-label="${esc(P.nome)}"><span aria-hidden="true">${nome(P, esc)}</span></h1>
          <p class="sobre">${esc(P.descricao || `${plural(Q.length, "quarto", "quartos")}${lugar ? " em " + lugar : ""}. Escolha as datas, veja o que está livre e mande seu pedido. A pousada confirma e você acompanha o estado do pedido numa página.`)}</p>
          <dl class="fatos"><div><dt>Entrada</dt><dd data-hora>${esc(P.checkin_hora)}</dd></div><div><dt>Saída</dt><dd data-hora>${esc(P.checkout_hora)}</dd></div><div><dt>Quartos</dt><dd data-num="${Q.length}">${Q.length}</dd></div>${precoMin ? `<div><dt>Diárias desde</dt><dd data-num="${precoMin}" data-reais>${brl(precoMin)}</dd></div>` : ""}</dl>
          ${zap || P.instagram ? `<div class="contato">${zap ? `<a class="btn btn--claro" href="${linkZap(`Olá! Vi o site da ${P.nome} e queria saber mais.`)}" target="_blank" rel="noopener">Falar no WhatsApp</a>` : ""}${P.instagram ? `<a class="btn btn--claro" href="https://instagram.com/${esc(P.instagram)}" target="_blank" rel="noopener">@${esc(P.instagram)}</a>` : ""}</div>` : ""}
        </div>
        <div class="hd-visual">${arco}
          <svg class="hd-selo" viewBox="0 0 120 120" aria-hidden="true" focusable="false"><defs><path id="hd-circ" d="M60 60 m-46 0 a46 46 0 1 1 92 0 a46 46 0 1 1 -92 0"/></defs>
            <text font-size="${fs}" letter-spacing=".5"><textPath href="#hd-circ" textLength="283" lengthAdjust="spacing">${esc(txtSelo)}</textPath></text><g transform="translate(43 43) scale(.85)" class="hd-selo-sol">${SOL_G}</g></svg>
        </div>
        <form class="hd-bilhete" id="bilhete" novalidate aria-label="Buscar quartos livres">
          <div class="hd-papel">
            <div class="hd-corpo">
              <div class="hd-topo-b"><span>Bilhete de hospedagem</span><span>${esc(lugar || P.cidade || "")}</span></div>
              <div class="hd-rota">
                <label class="hd-d"><span>Chegada</span><input type="date" id="b-in" min="${hoje()}" value="${S.entrada}" required></label>
                <svg class="hd-trilha" viewBox="0 0 200 64" aria-hidden="true" focusable="false"><path class="hd-trilha-linha" d="M6 56 Q100 -16 194 56"/><circle class="hd-ponta" cx="6" cy="56" r="3.2"/><circle class="hd-ponta" cx="194" cy="56" r="3.2"/><circle class="hd-sol-rota" id="hd-sol-rota" r="7.5" cx="100" cy="20"/></svg>
                <label class="hd-d hd-d--fim"><span>Saída</span><input type="date" id="b-out" min="${addDias(hoje(), 1)}" value="${S.saida}" required></label>
              </div>
              <div class="hd-gente">
                <label class="hd-c"><span>Adultos</span><span class="contador"><button type="button" data-conta="adultos" data-d="-1" aria-label="Menos um adulto">−</button><output id="o-adultos">${S.adultos}</output><button type="button" data-conta="adultos" data-d="1" aria-label="Mais um adulto">+</button></span></label>
                <label class="hd-c"><span>Crianças</span><span class="contador"><button type="button" data-conta="criancas" data-d="-1" aria-label="Menos uma criança">−</button><output id="o-criancas">${S.criancas}</output><button type="button" data-conta="criancas" data-d="1" aria-label="Mais uma criança">+</button></span></label>
                <p class="noites" id="b-noites" aria-live="polite"></p>
                <svg class="hd-codigo" viewBox="0 0 150 30" aria-hidden="true" focusable="false">${codigoPinhos(P.nome)}</svg>
              </div>
            </div>
            <div class="hd-canhoto">
              <span class="hd-cn" aria-hidden="true"><b id="hd-n">1</b><i id="hd-nl">noite</i></span>
              <button class="btn btn--cheio" type="submit" id="b-ver">Ver quartos livres</button>
              <p class="erro" id="b-erro" role="alert" hidden></p>
            </div>
          </div>
        </form>
      </div></section>`;
    },

    // cada quarto é uma linha numerada, como num cardápio: nome, o que tem, preço e o botão
    quarto(c, q, e) {
      const { esc, plural } = c;
      return `<article class="q hd-q ${e.escolhido ? "escolhido" + (e.pulsa ? " pulsa" : "") : ""} ${e.fora ? "fora" : ""}">
        <span class="hd-n" aria-hidden="true"></span>
        ${q.foto_url ? `<img class="hd-qf" src="${esc(q.foto_url)}" alt="Foto do ${esc(q.nome)}" loading="lazy">` : ""}
        <div class="hd-qc"><h3>${esc(q.nome)}</h3><p class="tipo">${esc(q.tipo || "Quarto")}, para até ${plural(q.capacidade, "pessoa", "pessoas")}</p>${q.descricao ? `<p class="desc">${esc(q.descricao)}</p>` : ""}${e.situ}</div>
        <div class="hd-qp"><span class="preco">${e.preco}</span>${e.acao}</div></article>`;
    },

    // o rodapé é o fim do dia: pinheiros contra o céu, o sol se pondo atrás deles e o mar embaixo
    rodape(c) {
      const { P, CASA, slug, esc, lugar } = c;
      // pinheiros em duas fileiras (a de trás mais clara e baixa); cada árvore é um <g> com a posição e um <path> dentro, que é o que balança.
      // A imagem tem folga em cima (altura 130) para a ponta dos mais altos não ser cortada.
      const arvore = (x, s, cls) => `<g transform="translate(${x.toFixed(0)} ${(130 - 97 * s).toFixed(1)}) scale(${s.toFixed(2)})"><path class="${cls}" d="${PINHEIRO_D}"/></g>`;
      const atras = Array.from({ length: 22 }, (_, i) => arvore(i * 72 + 14 + ((i * 41) % 17), .5 + ((i * 29) % 7) / 22, "b")).join("");
      const frente = Array.from({ length: 24 }, (_, i) => arvore(i * 66 - 18 + ((i * 53) % 27), .6 + ((i * 37) % 9) / 18, "f")).join("");
      const pinhos = atras + frente;
      return `<footer class="rodape hd-rodape">${bando(c, "hd-voo--pinhal")}<svg class="hd-pinhal" viewBox="0 0 1470 130" preserveAspectRatio="xMidYMax slice" aria-hidden="true" focusable="false">${pinhos}</svg>
        <div class="hd-mar"><div class="hd-ondas" aria-hidden="true"><svg viewBox="0 0 2400 60" preserveAspectRatio="none"><path d="${onda(30, 14, 600)} L2400 60 L0 60 Z"/></svg><svg viewBox="0 0 2400 60" preserveAspectRatio="none"><path d="${onda(34, 10, 400)} L2400 60 L0 60 Z"/></svg></div>
          <div class="dentro hd-rod"><span class="hd-rod-nome">${esc(P.nome)}${lugar ? `<small>${esc(lugar)}</small>` : ""}</span>
            <span class="hd-rod-links">${P.email ? `<a href="mailto:${esc(P.email)}">${esc(P.email)}</a>` : ""}<a href="reserva.html?p=${encodeURIComponent(slug)}">Acompanhar pedido</a>${CASA ? '<a href="#sobre">Sobre a casa</a>' : ""}<a href="privacidade.html?p=${encodeURIComponent(slug)}">Aviso de Privacidade</a></span></div></div></footer>`;
    },

    // céu e sol ficam fixos atrás da página; o sol desce e o céu escurece conforme o hóspede rola
    fim(c, mov) {
      const r = document.documentElement;
      if (!document.getElementById("ceu")) document.body.insertAdjacentHTML("afterbegin", '<div id="ceu" aria-hidden="true"></div><div id="sol" aria-hidden="true"></div>');
      const sol = document.getElementById("sol"); let pedido = false;
      const ease = t => t * t * (3 - 2 * t);
      const atualiza = () => {
        pedido = false;
        const h = r.scrollHeight - innerHeight, p = h > 0 ? Math.min(1, Math.max(0, scrollY / h)) : 0;
        r.style.setProperty("--sol", p.toFixed(4));
        const mar = document.querySelector(".hd-mar"), d = sol.offsetHeight, y0 = innerHeight * .09, y1 = innerHeight - (mar ? mar.offsetHeight : 120) - d * .38;
        sol.style.transform = `translate3d(0, ${(y0 + (y1 - y0) * ease(p)).toFixed(1)}px, 0)`;
      };
      if (mov) { addEventListener("scroll", () => { if (!pedido) { pedido = true; requestAnimationFrame(atualiza); } }, { passive: true }); addEventListener("resize", atualiza); }
      // bilhete: o sol percorre o arco entre a chegada e a saída quando as datas mudam; o canhoto mostra quantas noites
      const sc = document.getElementById("hd-sol-rota"), P0 = [6, 56], P1 = [100, -16], P2 = [194, 56];
      const ponto = t => [0, 1].map(k => (1 - t) * (1 - t) * P0[k] + 2 * (1 - t) * t * P1[k] + t * t * P2[k]);
      const poe = t => { const [x, y] = ponto(t); sc.setAttribute("cx", x.toFixed(1)); sc.setAttribute("cy", y.toFixed(1)); };
      let anim = 0;
      const viaja = () => { poe(.5); if (!mov) return; cancelAnimationFrame(anim); const t0 = performance.now(), dur = 1300; // sai da chegada e sobe até o meio do arco
        const passo = now => { const u = Math.min(1, (now - t0) / dur), e = 1 - Math.pow(1 - u, 3); poe(e * .5); if (u < 1) anim = requestAnimationFrame(passo); }; anim = requestAnimationFrame(passo); };
      const noitesTxt = () => { const a = Date.parse($v("b-in")), b = Date.parse($v("b-out")), n = a && b && b > a ? Math.round((b - a) / 864e5) : 0; document.getElementById("hd-n").textContent = n || "–"; document.getElementById("hd-nl").textContent = n === 1 ? "noite" : "noites"; };
      const $v = id => document.getElementById(id).value;
      ["b-in", "b-out"].forEach(id => document.getElementById(id).addEventListener("change", () => { setTimeout(noitesTxt, 0); viaja(); }));
      noitesTxt(); poe(.5);
      atualiza(); if (document.fonts) document.fonts.ready.then(atualiza);
    }
  };
})();
