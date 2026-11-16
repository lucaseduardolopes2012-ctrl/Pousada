---
version: 1
slug: "painel-html"
primary_target: "painel.html"
related_targets: ["site.html","comecar.html"]
---

# Surface brief: painel da pousada (and the shared world for cadastro, site, termos)

Scope: painel.html (Operate), comecar.html (Operate), site.html (Persuade, per-pousada), termos/privacidade (Read), 404.
Audience: dono ou recepção de pousada pequena, no balcão ou no celular; hóspede no celular.
Job: saber de relance quem está, quem sai, quem atrasou e quem chega; confirmar pedidos do site.
Constraints: static HTML/JS, Supabase, CSP (Google Fonts, jsDelivr, cdnjs). Keep every behavior.

## Direction contract

THESIS: The pousada's day reads like a tábua de marés: movements listed by the hour in tabular columns, occupancy drawn as a tide curve. Refuses the SaaS dashboard of four KPI tiles over a bar chart.

OWN-WORLD: Nautical-chart publication. Shell rail in carta-náutica deep blue; ground a pale chart-water tint (not cream, not white); land buff for "livre" and quiet fills; chart magenta for anything needing action (pedido, atraso). Hairline rules, tabular condensed numerals for every time/date/price, a hyperlegible sans for words.

STORY: Owner opens the painel, sees today's tábua (hora, movimento, quarto, hóspede) and acts on the top row; sees the next weeks' preamar/baixa-mar of occupancy; confirms site requests.

FIRST VIEWPORT: Left rail (nav). Main: heading with date and one-line summary; pedidos strip if any (magenta); two columns: "Tábua de hoje" table by time with action buttons; tide curve of occupancy 14 days with today's marker and labels "Cheia" and "Vazia". Primary action "Registrar estadia" top right.

FORM: grounded candidate 3 of 7 (tábua de marés); seed:e7422729a600c8b5. Raises: hairline-ruled modules with no card padding inflation (from japanese-high-density-web); every stay and room identified by its number first (from brand-identity-canon-saville-catalog-sleeve).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
