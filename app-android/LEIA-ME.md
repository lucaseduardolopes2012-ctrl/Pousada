# App do painel (Android)

Abre o painel publicado (pousada-gestao-theta.vercel.app/painel.html) numa janela própria, com ícone na tela inicial.
Guarda o login, envia fotos da galeria, abre WhatsApp/telefone/e-mail nos apps do celular e mostra um aviso quando falta internet.
Como o app carrega o painel do site, toda mudança publicada no painel já aparece no app sem precisar gerar outro APK.

## Gerar o APK
1. Android SDK (platforms;android-34, build-tools;34.0.0) e Java 17+.
2. `local.properties` com `sdk.dir=/caminho/do/android-sdk`.
3. `assinatura.properties` com `arquivo=painel-pousada.jks`, `senha=...`, `apelido=painel` (e o .jks nesta pasta). Nunca vai para o git.
4. `gradle assembleRelease` → `app/build/outputs/apk/release/app-release.apk`.

Para atualizar um app já instalado, use SEMPRE a mesma chave (.jks) e aumente `versionCode` em app/build.gradle.

## Avisos de pedido novo (Firebase)
- Coloque o `google-services.json` do projeto Firebase em `app-android/app/` e gere o APK de novo.
- No Supabase → Edge Functions → Secrets, crie `FCM_CONTA` com o JSON inteiro da conta de serviço do Firebase.
- O banco (migracao_v19.sql) chama a função `avisa-reserva` (supabase/functions) a cada pedido vindo do site.
