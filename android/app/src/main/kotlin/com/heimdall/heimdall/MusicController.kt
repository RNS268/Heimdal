package com.heimdall.heimdall

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import android.content.ComponentName
import io.flutter.plugin.common.EventChannel
import java.io.ByteArrayOutputStream

class MusicController(private val context: Context) {

    private var mediaSessionManager: MediaSessionManager? = null
    private var mediaController: MediaController? = null
    private var eventSink: EventChannel.EventSink? = null

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun initialize() {
        try {
            mediaSessionManager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            updateActiveController()
            registerCallbacks()
        } catch (e: Exception) {
            Log.e("MusicController", "Failed to initialize: ${e.message}")
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun registerCallbacks() {
        mediaController?.registerCallback(object : MediaController.Callback() {
            override fun onMetadataChanged(metadata: android.media.MediaMetadata?) {
                super.onMetadataChanged(metadata)
                sendMetadataUpdate()
            }

            override fun onPlaybackStateChanged(state: PlaybackState?) {
                super.onPlaybackStateChanged(state)
                sendMetadataUpdate()
            }
        })
    }

    fun checkNotificationPermission(): Boolean {
        val componentName = ComponentName(context, HelmetNotificationListener::class.java)
        val enabledListeners = android.provider.Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        return enabledListeners?.contains(componentName.flattenToString()) == true
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun updateActiveController() {
        try {
            val component = ComponentName(context, HelmetNotificationListener::class.java)
            val sessions = mediaSessionManager?.getActiveSessions(component)
            mediaController = sessions?.firstOrNull()
            registerCallbacks()
        } catch (e: Exception) {
            Log.e("MusicController", "Failed to get active sessions: ${e.message}")
        }
    }

    private fun sendMetadataUpdate() {
        val metadata = getCurrentTrack()
        eventSink?.success(metadata)
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun playPause() {
        try {
            updateActiveController()
            if (mediaController != null) {
                val playbackState = mediaController?.playbackState?.state
                if (playbackState == PlaybackState.STATE_PLAYING) {
                    mediaController?.transportControls?.pause()
                } else {
                    mediaController?.transportControls?.play()
                }
                sendMetadataUpdate()
            } else {
                sendFallbackMediaKey(android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            }
        } catch (e: Exception) {
            Log.e("MusicController", "Failed to play/pause: ${e.message}")
            sendFallbackMediaKey(android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun next() {
        try {
            updateActiveController()
            if (mediaController != null) {
                mediaController?.transportControls?.skipToNext()
                sendMetadataUpdate()
            } else {
                sendFallbackMediaKey(android.view.KeyEvent.KEYCODE_MEDIA_NEXT)
            }
        } catch (e: Exception) {
            Log.e("MusicController", "Failed to skip next: ${e.message}")
            sendFallbackMediaKey(android.view.KeyEvent.KEYCODE_MEDIA_NEXT)
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun previous() {
        try {
            updateActiveController()
            if (mediaController != null) {
                mediaController?.transportControls?.skipToPrevious()
                sendMetadataUpdate()
            } else {
                sendFallbackMediaKey(android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            }
        } catch (e: Exception) {
            Log.e("MusicController", "Failed to skip previous: ${e.message}")
            sendFallbackMediaKey(android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS)
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun seekTo(positionMs: Long) {
        try {
            updateActiveController()
            mediaController?.transportControls?.seekTo(positionMs)
            sendMetadataUpdate()
        } catch (e: Exception) {
            Log.e("MusicController", "Failed to seek: ${e.message}")
        }
    }

    private fun sendFallbackMediaKey(keyCode: Int) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
            audioManager.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, keyCode))
            audioManager.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, keyCode))
        } catch (e: Exception) {
            Log.e("MusicController", "Fallback key dispatch failed: ${e.message}")
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun getCurrentTrack(): Map<String, Any?> {
        return try {
            val component = ComponentName(context, HelmetNotificationListener::class.java)
            val sessions = mediaSessionManager?.getActiveSessions(component)
            
            // Try to find an actively playing session, otherwise fallback to any session
            mediaController = sessions?.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING } 
                ?: sessions?.firstOrNull()

            if (mediaController == null) {
                return mapOf(
                    "title" to "No Media",
                    "artist" to "Sessions: ${sessions?.size ?: 0}",
                    "duration" to 0L,
                    "position" to 0L,
                    "isPlaying" to false,
                    "albumArt" to null
                )
            }

            val metadata = mediaController?.metadata
            val playbackState = mediaController?.playbackState
            val albumArtBitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
            val albumArtBytes = albumArtBitmap?.let { bitmap ->
                ByteArrayOutputStream().use { stream ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    stream.toByteArray()
                }
            }

            var title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
                ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
            
            var artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE)
            
            if (title.isNullOrBlank()) title = "Unknown Title"
            if (artist.isNullOrBlank()) artist = "Unknown Artist"

            mapOf(
                "title" to title,
                "artist" to artist,
                "album" to (metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: "Unknown"),
                "duration" to (metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L),
                "position" to (playbackState?.position ?: 0L),
                "isPlaying" to (playbackState?.state == PlaybackState.STATE_PLAYING),
                "albumArt" to albumArtBytes
            )
        } catch (e: SecurityException) {
            Log.e("MusicController", "SecurityException: ${e.message}")
            mapOf(
                "title" to "Permission Denied",
                "artist" to "Toggle Notification Access",
                "duration" to 0L,
                "position" to 0L,
                "isPlaying" to false,
                "albumArt" to null
            )
        } catch (e: Exception) {
            Log.e("MusicController", "Failed to get current track: ${e.message}")
            mapOf(
                "title" to "Error",
                "artist" to (e.message?.take(30) ?: "Unknown Error"),
                "duration" to 0L,
                "position" to 0L,
                "isPlaying" to false,
                "albumArt" to null
            )
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun setVolume(volume: Float) {
        try {
            updateActiveController()
            mediaController?.setVolumeTo((volume * 100).toInt(), 0)
        } catch (e: Exception) {
            Log.e("MusicController", "Failed to set volume: ${e.message}")
        }
    }
}