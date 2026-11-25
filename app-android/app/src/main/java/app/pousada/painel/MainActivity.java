package app.pousada.painel;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.os.Message;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ProgressBar;
import android.widget.Toast;

/**
 * App do dono da pousada: abre o painel publicado dentro de uma janela própria,
 * guarda o login, envia fotos da galeria/câmera e manda links de WhatsApp,
 * telefone e e-mail para os apps certos do celular.
 */
public class MainActivity extends Activity {
    private static final String PAINEL = "https://pousada-gestao-theta.vercel.app/painel.html";
    private static final String HOST = "pousada-gestao-theta.vercel.app";
    private static final int ESCOLHER_ARQUIVO = 41;

    private FrameLayout raiz;
    private WebView web;
    private WebView janela; // janela aberta pelo painel (ex.: QR code para imprimir)
    private ProgressBar barra;
    private ValueCallback<Uri[]> aguardandoArquivo;
    private boolean mostrandoErro = false;

    @Override
    protected void onCreate(Bundle salvo) {
        super.onCreate(salvo);
        raiz = new FrameLayout(this);
        raiz.setBackgroundColor(Color.WHITE);

        web = new WebView(this);
        configura(web);
        raiz.addView(web, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        barra = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        barra.setMax(100);
        barra.setProgressTintList(android.content.res.ColorStateList.valueOf(Color.parseColor("#e30613")));
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(3));
        raiz.addView(barra, lp);
        setContentView(raiz);

        CookieManager cm = CookieManager.getInstance();
        cm.setAcceptCookie(true);
        cm.setAcceptThirdPartyCookies(web, true);

        if (salvo != null) web.restoreState(salvo);
        else web.loadUrl(PAINEL);

        preparaAvisos();
    }

    /** Avisos de pedido novo: cria o canal, pede permissão (Android 13+) e pega o endereço deste celular no Firebase. */
    private void preparaAvisos() {
        Avisos.criaCanal(this);
        if (android.os.Build.VERSION.SDK_INT >= 33
                && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS}, 7);
        }
        try {
            com.google.firebase.messaging.FirebaseMessaging.getInstance().getToken().addOnSuccessListener(t ->
                    getSharedPreferences(Avisos.PREFS, MODE_PRIVATE).edit().putString("token", t).apply());
        } catch (Exception e) {
            // app gerado sem o google-services.json: funciona, só não recebe avisos
        }
    }

    /** O painel pergunta o endereço do celular por aqui e cadastra no banco (salvar_push_token). */
    private class Ponte {
        @JavascriptInterface
        public String token() {
            return getSharedPreferences(Avisos.PREFS, MODE_PRIVATE).getString("token", "");
        }
    }

    @Override
    protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        if (web != null && !mostrandoErro) web.reload(); // tocou no aviso: mostra o pedido novo
    }

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    private void configura(WebView w) {
        WebSettings s = w.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);          // o login do painel fica salvo aqui
        s.setDatabaseEnabled(true);
        s.setJavaScriptCanOpenWindowsAutomatically(true);
        s.setSupportMultipleWindows(true);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);
        s.setMediaPlaybackRequiresUserGesture(true);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setUserAgentString(s.getUserAgentString() + " PainelPousadaApp/1.0");

        w.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest req) {
                return trataLink(v, req.getUrl());
            }

            @Override
            public void onPageStarted(WebView v, String url, Bitmap f) { if (v == web) barra.setVisibility(View.VISIBLE); }

            @Override
            public void onPageFinished(WebView v, String url) {
                if (v == web) barra.setVisibility(View.GONE);
                CookieManager.getInstance().flush();
            }

            @Override
            public void onReceivedError(WebView v, WebResourceRequest req, WebResourceError err) {
                if (v == web && req.isForMainFrame()) mostraSemInternet();
            }
        });

        w.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView v, int p) { if (v == web) barra.setProgress(p); }

            @Override
            public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams params) {
                if (aguardandoArquivo != null) aguardandoArquivo.onReceiveValue(null);
                aguardandoArquivo = cb;
                Intent i = new Intent(Intent.ACTION_GET_CONTENT);
                i.addCategory(Intent.CATEGORY_OPENABLE);
                i.setType("image/*");
                if (params.getMode() == FileChooserParams.MODE_OPEN_MULTIPLE) i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                try {
                    startActivityForResult(Intent.createChooser(i, "Escolha a foto"), ESCOLHER_ARQUIVO);
                } catch (ActivityNotFoundException e) {
                    aguardandoArquivo = null;
                    Toast.makeText(MainActivity.this, "Nenhum app de fotos encontrado.", Toast.LENGTH_LONG).show();
                    return false;
                }
                return true;
            }

            @Override
            public boolean onCreateWindow(WebView v, boolean dialogo, boolean gesto, Message msg) {
                fechaJanela();
                janela = new WebView(MainActivity.this);
                configura(janela);
                janela.setBackgroundColor(Color.WHITE);
                raiz.addView(janela, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                ((WebView.WebViewTransport) msg.obj).setWebView(janela);
                msg.sendToTarget();
                return true;
            }

            @Override
            public void onCloseWindow(WebView v) { if (v == janela) fechaJanela(); }
        });

        if (w == web) w.addJavascriptInterface(new Ponte(), "PainelApp");
        w.setDownloadListener((url, ua, cd, tipo, tam) -> abreFora(Uri.parse(url)));
    }

    /** Links do próprio painel ficam no app; WhatsApp, telefone, e-mail e sites de fora abrem no app certo. */
    private boolean trataLink(WebView v, Uri u) {
        String esquema = u.getScheme() == null ? "" : u.getScheme();
        String host = u.getHost() == null ? "" : u.getHost();
        if (esquema.equals("https") && host.equals(HOST)) {
            // o site dos hóspedes abre no navegador, para o dono ver como o cliente vê
            String caminho = u.getPath() == null ? "" : u.getPath();
            if (v == web && (caminho.startsWith("/site") || caminho.startsWith("/reserva"))) { abreFora(u); return true; }
            return false;
        }
        if (esquema.equals("about") || esquema.equals("data") || esquema.equals("blob")) return false;
        abreFora(u);
        if (v == janela) fechaJanela();
        return true;
    }

    private void abreFora(Uri u) {
        try {
            Intent i = "intent".equals(u.getScheme())
                    ? Intent.parseUri(u.toString(), Intent.URI_INTENT_SCHEME)
                    : new Intent(Intent.ACTION_VIEW, u);
            i.addCategory(Intent.CATEGORY_BROWSABLE);
            i.setComponent(null);
            i.setSelector(null);
            startActivity(i);
        } catch (Exception e) {
            Toast.makeText(this, "Não achei um app para abrir esse link.", Toast.LENGTH_LONG).show();
        }
    }

    private void fechaJanela() {
        if (janela != null) {
            raiz.removeView(janela);
            janela.destroy();
            janela = null;
        }
    }

    private void mostraSemInternet() {
        mostrandoErro = true;
        String html = "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
                + "<style>body{font-family:sans-serif;display:grid;place-items:center;min-height:90vh;margin:0;color:#13294b;text-align:center;padding:24px}"
                + "h1{font-size:22px}p{color:#555}button{background:#e30613;color:#fff;border:0;border-radius:12px;padding:14px 26px;font-size:17px}</style></head>"
                + "<body><div><h1>Sem internet</h1><p>O painel precisa de conexão para mostrar as reservas.<br>Confira o Wi-Fi ou os dados móveis.</p>"
                + "<button onclick=\"location.href='" + PAINEL + "'\">Tentar de novo</button></div></body></html>";
        web.loadDataWithBaseURL("https://" + HOST + "/", html, "text/html", "utf-8", null);
    }

    @Override
    protected void onActivityResult(int pedido, int resultado, Intent dados) {
        if (pedido == ESCOLHER_ARQUIVO && aguardandoArquivo != null) {
            Uri[] escolhidos = null;
            if (resultado == RESULT_OK && dados != null) {
                if (dados.getClipData() != null) {
                    int n = dados.getClipData().getItemCount();
                    escolhidos = new Uri[n];
                    for (int k = 0; k < n; k++) escolhidos[k] = dados.getClipData().getItemAt(k).getUri();
                } else if (dados.getData() != null) {
                    escolhidos = new Uri[]{dados.getData()};
                }
            }
            aguardandoArquivo.onReceiveValue(escolhidos);
            aguardandoArquivo = null;
            return;
        }
        super.onActivityResult(pedido, resultado, dados);
    }

    @Override
    public void onBackPressed() {
        if (janela != null) { fechaJanela(); return; }
        if (mostrandoErro) { mostrandoErro = false; web.loadUrl(PAINEL); return; }
        if (web.canGoBack()) { web.goBack(); return; }
        moveTaskToBack(true); // sai sem fechar: o login continua aberto
    }

    @Override
    protected void onResume() { super.onResume(); web.onResume(); }

    @Override
    protected void onPause() { CookieManager.getInstance().flush(); web.onPause(); super.onPause(); }

    @Override
    protected void onSaveInstanceState(Bundle out) { super.onSaveInstanceState(out); web.saveState(out); }

    @Override
    protected void onDestroy() { fechaJanela(); web.destroy(); super.onDestroy(); }
}
