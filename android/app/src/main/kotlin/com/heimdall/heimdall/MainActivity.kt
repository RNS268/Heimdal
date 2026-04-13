package com.heimdall.heimdall

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.telephony.SmsManager
import android.util.Log
import androidx.annotation.NonNull

class MainActivity : FlutterActivity() {
    private val EMERGENCY_CHANNEL = "com.heimdall.helmet/emergency_calls"
    private val MUSIC_CHANNEL = "com.heimdall.music"
    private var sosToneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Emergency calls channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMERGENCY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "makeEmergencyCall" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        val contactName = call.argument<String>("contactName")
                        val latitude = call.argument<Double>("latitude")
                        val longitude = call.argument<Double>("longitude")

                        if (phoneNumber != null && latitude != null && longitude != null) {
                            try {
                                val success = makeEmergencyCall(
                                    phoneNumber,
                                    contactName ?: "Emergency",
                                    latitude,
                                    longitude
                                )
                                result.success(success)
                            } catch (e: Exception) {
                                Log.e("EmergencyCall", "Error making call: ${e.message}")
                                result.success(false)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Missing required arguments", null)
                        }
                    }
                    "sendEmergencySms" -> {
                        val message = call.argument<String>("message")
                        val recipients = call.argument<List<String>>("recipients")

                        if (message != null && recipients != null) {
                            try {
                                val success = sendEmergencySms(message, recipients)
                                result.success(success)
                            } catch (e: Exception) {
                                Log.e("EmergencySms", "Error sending SMS: ${e.message}")
                                result.success(false)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Missing required arguments", null)
                        }
                    }
                    "startSosTone" -> {
                        try {
                            val success = startSosTone()
                            result.success(success)
                        } catch (e: Exception) {
                            Log.e("EmergencyTone", "Error starting SOS tone: ${e.message}")
                            result.success(false)
                        }
                    }
                    "stopSosTone" -> {
                        try {
                            val success = stopSosTone()
                            result.success(success)
                        } catch (e: Exception) {
                            Log.e("EmergencyTone", "Error stopping SOS tone: ${e.message}")
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Music control channel
        val musicController = MusicController(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MUSIC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        val hasPermission = musicController.checkNotificationPermission()
                        if (!hasPermission) {
                            val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                        }
                        musicController.initialize()
                        result.success(null)
                    }
                    "playPause" -> {
                        musicController.playPause()
                        result.success(null)
                    }
                    "next" -> {
                        musicController.next()
                        result.success(null)
                    }
                    "previous" -> {
                        musicController.previous()
                        result.success(null)
                    }
                    "getCurrentTrack" -> {
                        val trackInfo = musicController.getCurrentTrack()
                        result.success(trackInfo)
                    }
                    "setVolume" -> {
                        val volume = call.argument<Double>("volume") ?: 0.5
                        musicController.setVolume(volume.toFloat())
                        result.success(null)
                    }
                    "seekTo" -> {
                        val position = call.argument<Int>("position")?.toLong() ?: 0L
                        musicController.seekTo(position)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Music events channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$MUSIC_CHANNEL/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    musicController.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    musicController.setEventSink(null)
                }
            })
    }

    private fun makeEmergencyCall(
        phoneNumber: String,
        contactName: String,
        latitude: Double,
        longitude: Double
    ): Boolean {
        return try {
            // Remove any non-digit characters except + at the beginning
            val cleanPhone = if (phoneNumber.startsWith("+")) {
                "+" + phoneNumber.drop(1).filter { it.isDigit() }
            } else {
                phoneNumber.filter { it.isDigit() }
            }

            Log.d("EmergencyCall", "Initiating call to: $cleanPhone ($contactName)")
            Log.d("EmergencyCall", "Location: $latitude, $longitude")

            // Create intent to call
            val callIntent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:$cleanPhone")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }

            // Check permission and make call
            startActivity(callIntent)
            
            Log.d("EmergencyCall", "Call initiated successfully")
            true
        } catch (e: SecurityException) {
            Log.e("EmergencyCall", "Security exception - CALL_PHONE permission may not be granted: ${e.message}")
            false
        } catch (e: Exception) {
            Log.e("EmergencyCall", "Exception during call: ${e.message}")
            false
        }
    }

    private fun startSosTone(): Boolean {
        return try {
            stopSosTone()
            sosToneGenerator = ToneGenerator(AudioManager.STREAM_ALARM, 100)
            sosToneGenerator?.startTone(ToneGenerator.TONE_SUP_ERROR, 10000)
            Log.d("EmergencyTone", "SOS tone started (TONE_SUP_ERROR for 10s)")
            true
        } catch (e: Exception) {
            Log.e("EmergencyTone", "Error starting SOS tone: ${e.message}")
            false
        }
    }

    private fun stopSosTone(): Boolean {
        return try {
            sosToneGenerator?.stopTone()
            sosToneGenerator?.release()
            sosToneGenerator = null
            Log.d("EmergencyTone", "SOS tone stopped")
            true
        } catch (e: Exception) {
            Log.e("EmergencyTone", "Error stopping SOS tone: ${e.message}")
            false
        }
    }

    private fun sendEmergencySms(message: String, recipients: List<String>): Boolean {
        return try {
            val smsManager = SmsManager.getDefault()
            recipients.forEach { recipient ->
                val cleanPhone = if (recipient.startsWith("+")) {
                    "+" + recipient.drop(1).filter { it.isDigit() }
                } else {
                    recipient.filter { it.isDigit() }
                }

                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(cleanPhone, null, parts, null, null)
            }
            Log.d("EmergencySms", "SMS sent successfully to $recipients")
            true
        } catch (e: SecurityException) {
            Log.e("EmergencySms", "Security exception - SEND_SMS permission may not be granted: ${e.message}")
            false
        } catch (e: Exception) {
            Log.e("EmergencySms", "Exception sending SMS: ${e.message}")
            false
        }
    }
}

