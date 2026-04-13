package com.heimdall.heimdall

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class HelmetNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        // We solely use this service as a permission token for MediaSessionManager
        // which allows MusicController to fetch Album Art and live Seek data!
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }
}
