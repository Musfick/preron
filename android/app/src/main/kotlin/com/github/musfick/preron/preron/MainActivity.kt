package com.github.musfick.preron.preron

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.text.TextUtils
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL        = "com.github.musfick.preron.preron/ussd"
        private const val EVENT_CHANNEL         = "com.github.musfick.preron.preron/ussd_events"
        private const val CALL_PHONE_REQUEST    = 1001
        private const val OVERLAY_PERMISSION_RC = 1002
        private const val TAG                   = "MAIN_ACTIVITY"
    }

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── EventChannel ──────────────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(args: Any?) { eventSink = null }
            })

        // ── MethodChannel ─────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Accessibility check ────────────────────────────────
                    "checkAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    // ── Overlay permission ─────────────────────────────────
                    "checkOverlayPermission" -> {
                        result.success(hasOverlayPermission())
                    }

                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            !Settings.canDrawOverlays(this)
                        ) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivityForResult(intent, OVERLAY_PERMISSION_RC)
                        }
                        result.success(null)
                    }

                    // ── Overlay service control ────────────────────────────
                    "startOverlay" -> {
                        if (!hasOverlayPermission()) {
                            result.error("NO_OVERLAY_PERMISSION",
                                "SYSTEM_ALERT_WINDOW permission required", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(this, UssdOverlayService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }

                    "stopOverlay" -> {
                        stopService(Intent(this, UssdOverlayService::class.java))
                        result.success(true)
                    }

                    "clearOverlayLogs" -> {
                        startService(
                            Intent(this, UssdOverlayService::class.java)
                                .setAction(UssdOverlayService.ACTION_CLEAR)
                        )
                        result.success(null)
                    }

                    // ── Get SIM list ───────────────────────────────────────
                    "getSimCards" -> {
                        if (!hasPhoneStatePermission()) {
                            requestPhoneStatePermission()
                            result.error("NO_PERMISSION",
                                "READ_PHONE_STATE permission required", null)
                            return@setMethodCallHandler
                        }
                        result.success(getSimCardList())
                    }

                    // ── Balance Check ──────────────────────────────────────
                    "checkBalance" -> {
                        val pin      = call.argument<String>("pin") ?: ""
                        val simIndex = call.argument<Int>("simIndex") ?: 0

                        if (!ensurePermissions(result)) return@setMethodCallHandler
                        if (!isAccessibilityServiceEnabled()) {
                            result.error("NO_ACCESSIBILITY",
                                "Enable the USSD accessibility service first", null)
                            return@setMethodCallHandler
                        }

                        // Auto-start overlay if permission granted
                        maybeStartOverlay()

                        UssdAccessibilityService.apply {
                            currentTask  = UssdAccessibilityService.UssdTask.BALANCE_CHECK
                            this.pin     = pin
                            isRunning    = true
                            currentStep  = 0
                            lastDialogText = ""
                            onResult = { dialogText ->
                                runOnUiThread {
                                    eventSink?.success(mapOf(
                                        "task"   to "checkBalance",
                                        "status" to "success",
                                        "result" to dialogText
                                    ))
                                }
                                result.success(dialogText)
                            }
                            onError = { errorMsg ->
                                runOnUiThread {
                                    eventSink?.success(mapOf(
                                        "task"   to "checkBalance",
                                        "status" to "error",
                                        "result" to errorMsg
                                    ))
                                }
                                result.error("USSD_ERROR", errorMsg, null)
                            }
                        }

                        dialUssdOnSim("*247#", simIndex)
                        Log.d(TAG, "Balance check → SIM index $simIndex, PIN=****")
                    }

                    // ── Send Money ─────────────────────────────────────────
                    "sendMoney" -> {
                        val pin         = call.argument<String>("pin") ?: ""
                        val simIndex    = call.argument<Int>("simIndex") ?: 0
                        val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                        val amount      = call.argument<String>("amount") ?: ""
                        val reference   = call.argument<String>("reference") ?: ""

                        if (!ensurePermissions(result)) return@setMethodCallHandler
                        if (!isAccessibilityServiceEnabled()) {
                            result.error("NO_ACCESSIBILITY",
                                "Enable the USSD accessibility service first", null)
                            return@setMethodCallHandler
                        }

                        maybeStartOverlay()

                        UssdAccessibilityService.apply {
                            currentTask        = UssdAccessibilityService.UssdTask.SEND_MONEY
                            this.pin           = pin
                            this.phoneNumber   = phoneNumber
                            this.amount        = amount
                            this.reference     = reference
                            isRunning          = true
                            currentStep        = 0
                            lastDialogText     = ""
                            onResult = { dialogText ->
                                runOnUiThread {
                                    eventSink?.success(mapOf(
                                        "task"   to "sendMoney",
                                        "status" to "success",
                                        "result" to dialogText
                                    ))
                                }
                                result.success(dialogText)
                            }
                            onError = { errorMsg ->
                                runOnUiThread {
                                    eventSink?.success(mapOf(
                                        "task"   to "sendMoney",
                                        "status" to "error",
                                        "result" to errorMsg
                                    ))
                                }
                                result.error("USSD_ERROR", errorMsg, null)
                            }
                        }

                        dialUssdOnSim("*247#", simIndex)
                        Log.d(TAG, "Send money → SIM index $simIndex, to=$phoneNumber, amount=$amount")
                    }

                    // ── Cash Out ───────────────────────────────────────────
                    "cashOut" -> {
                        val pin         = call.argument<String>("pin") ?: ""
                        val simIndex    = call.argument<Int>("simIndex") ?: 0
                        val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                        val amount      = call.argument<String>("amount") ?: ""

                        if (!ensurePermissions(result)) return@setMethodCallHandler
                        if (!isAccessibilityServiceEnabled()) {
                            result.error("NO_ACCESSIBILITY",
                                "Enable the USSD accessibility service first", null)
                            return@setMethodCallHandler
                        }

                        maybeStartOverlay()

                        UssdAccessibilityService.apply {
                            currentTask        = UssdAccessibilityService.UssdTask.CASH_OUT
                            this.pin           = pin
                            this.phoneNumber   = phoneNumber
                            this.amount        = amount
                            this.reference     = ""
                            isRunning          = true
                            currentStep        = 0
                            lastDialogText     = ""
                            onResult = { dialogText ->
                                runOnUiThread {
                                    eventSink?.success(mapOf(
                                        "task"   to "cashOut",
                                        "status" to "success",
                                        "result" to dialogText
                                    ))
                                }
                                result.success(dialogText)
                            }
                            onError = { errorMsg ->
                                runOnUiThread {
                                    eventSink?.success(mapOf(
                                        "task"   to "cashOut",
                                        "status" to "error",
                                        "result" to errorMsg
                                    ))
                                }
                                result.error("USSD_ERROR", errorMsg, null)
                            }
                        }

                        dialUssdOnSim("*247#", simIndex)
                        Log.d(TAG, "Cash out → SIM index $simIndex, to=$phoneNumber, amount=$amount")
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Overlay helpers
    // ─────────────────────────────────────────────────────────────────────
    private fun hasOverlayPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            Settings.canDrawOverlays(this)
        else true

    private fun maybeStartOverlay() {
        if (!hasOverlayPermission()) return
        if (UssdOverlayService.instance != null) return // already running
        val intent = Intent(this, UssdOverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
        else startService(intent)
    }

    // ─────────────────────────────────────────────────────────────────────
    //  SIM Card List
    // ─────────────────────────────────────────────────────────────────────
    private fun getSimCardList(): List<Map<String, Any?>> {
        val simList = mutableListOf<Map<String, Any?>>()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
            simList.add(mapOf(
                "simIndex"       to 0,
                "subscriptionId" to 0,
                "displayName"    to "SIM 1",
                "carrierName"    to "Unknown",
                "phoneNumber"    to "",
                "slotIndex"      to 0,
                "isActive"       to true
            ))
            return simList
        }

        val subscriptionManager =
            getSystemService(TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager

        val subscriptions = if (ActivityCompat.checkSelfPermission(
                this, Manifest.permission.READ_PHONE_STATE
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            subscriptionManager.activeSubscriptionInfoList
        } else null

        if (subscriptions.isNullOrEmpty()) return simList

        subscriptions.forEachIndexed { index, info ->
            val phoneNumber = getPhoneNumber(info.subscriptionId)
            simList.add(mapOf(
                "simIndex"       to index,
                "subscriptionId" to info.subscriptionId,
                "displayName"    to (info.displayName?.toString() ?: "SIM ${index + 1}"),
                "carrierName"    to (info.carrierName?.toString() ?: "Unknown"),
                "phoneNumber"    to (phoneNumber ?: ""),
                "slotIndex"      to info.simSlotIndex,
                "isActive"       to true
            ))
        }

        return simList
    }

    private fun getPhoneNumber(subscriptionId: Int): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (ActivityCompat.checkSelfPermission(
                        this, Manifest.permission.READ_PHONE_NUMBERS
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    val tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
                    tm.createForSubscriptionId(subscriptionId).line1Number
                } else null
            } else {
                val tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
                if (ActivityCompat.checkSelfPermission(
                        this, Manifest.permission.READ_PHONE_STATE
                    ) == PackageManager.PERMISSION_GRANTED
                ) tm.createForSubscriptionId(subscriptionId).line1Number else null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not get phone number for sub $subscriptionId: ${e.message}")
            null
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Dial USSD on specific SIM
    // ─────────────────────────────────────────────────────────────────────
    private fun dialUssdOnSim(ussdCode: String, simIndex: Int) {
        val encoded = Uri.encode(ussdCode)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val telecomManager = getSystemService(TELECOM_SERVICE) as TelecomManager
                val phoneAccounts = telecomManager.callCapablePhoneAccounts

                Log.d(TAG, "Available phone accounts: ${phoneAccounts.size}")

                if (simIndex < phoneAccounts.size) {
                    val handle: PhoneAccountHandle = phoneAccounts[simIndex]
                    val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$encoded")).apply {
                        putExtra(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, handle)
                    }
                    startActivity(intent)
                    Log.d(TAG, "Dialed on SIM index $simIndex via TelecomManager")
                    return
                }
            } catch (e: Exception) {
                Log.w(TAG, "TelecomManager dial failed: ${e.message} — falling back")
            }
        }

        Log.w(TAG, "Falling back to default SIM dial")
        startActivity(Intent(Intent.ACTION_CALL, Uri.parse("tel:$encoded")))
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Permissions
    // ─────────────────────────────────────────────────────────────────────
    private fun hasPhoneStatePermission() = ContextCompat.checkSelfPermission(
        this, Manifest.permission.READ_PHONE_STATE
    ) == PackageManager.PERMISSION_GRANTED

    private fun requestPhoneStatePermission() = ActivityCompat.requestPermissions(
        this,
        arrayOf(
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.READ_PHONE_NUMBERS
        ),
        CALL_PHONE_REQUEST
    )

    private fun ensurePermissions(result: MethodChannel.Result): Boolean {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.CALL_PHONE,
                    Manifest.permission.READ_PHONE_STATE,
                    Manifest.permission.READ_PHONE_NUMBERS
                ),
                CALL_PHONE_REQUEST
            )
            result.error("NO_PERMISSION", "CALL_PHONE permission required", null)
            return false
        }
        return true
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val service =
            "${packageName}/${UssdAccessibilityService::class.java.canonicalName}"
        var enabled = 0
        try {
            enabled = Settings.Secure.getInt(
                contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED
            )
        } catch (_: Exception) {}

        if (enabled != 1) return false

        val services = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(services)
        while (splitter.hasNext()) {
            if (splitter.next().equals(service, ignoreCase = true)) return true
        }
        return false
    }
}