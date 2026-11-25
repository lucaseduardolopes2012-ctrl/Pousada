package app.pousada.painel;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.media.RingtoneManager;
import android.os.Build;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

/** Recebe os avisos de pedido novo. Com o app fechado o Android mostra sozinho; com ele aberto, mostramos aqui. */
public class Avisos extends FirebaseMessagingService {
    static final String CANAL = "reservas";
    static final String PREFS = "painel";

    static void criaCanal(Context c) {
        if (Build.VERSION.SDK_INT < 26) return;
        NotificationChannel ch = new NotificationChannel(CANAL, "Pedidos de estadia", NotificationManager.IMPORTANCE_HIGH);
        ch.setDescription("Aviso quando um hóspede envia a ficha pelo site");
        ch.enableLights(true);
        ch.setLightColor(Color.RED);
        ch.enableVibration(true);
        c.getSystemService(NotificationManager.class).createNotificationChannel(ch);
    }

    @Override
    public void onNewToken(String token) {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString("token", token).apply();
    }

    @Override
    public void onMessageReceived(RemoteMessage m) {
        RemoteMessage.Notification n = m.getNotification();
        if (n == null) return;
        criaCanal(this);
        Intent abrir = new Intent(this, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pi = PendingIntent.getActivity(this, 0, abrir, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        android.app.Notification.Builder b = Build.VERSION.SDK_INT >= 26
                ? new android.app.Notification.Builder(this, CANAL)
                : new android.app.Notification.Builder(this).setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION));
        b.setSmallIcon(R.drawable.ic_aviso)
                .setColor(Color.parseColor("#e30613"))
                .setContentTitle(n.getTitle())
                .setContentText(n.getBody())
                .setStyle(new android.app.Notification.BigTextStyle().bigText(n.getBody()))
                .setAutoCancel(true)
                .setContentIntent(pi);
        String cod = m.getData().get("codigo");
        int id = cod != null ? cod.hashCode() : (int) System.currentTimeMillis();
        getSystemService(NotificationManager.class).notify(id, b.build());
    }
}
