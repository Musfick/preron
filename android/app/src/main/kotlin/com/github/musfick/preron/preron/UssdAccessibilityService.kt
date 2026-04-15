package com.github.musfick.preron.preron

import android.accessibilityservice.AccessibilityService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class UssdAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "USSD_SERVICE"

        var instance: UssdAccessibilityService? = null
        var currentTask: UssdTask = UssdTask.NONE
        var pin: String = ""
        var phoneNumber: String = ""
        var amount: String = ""
        var reference: String = ""
        var onResult: ((String) -> Unit)? = null
        var onError: ((String) -> Unit)? = null
        var isRunning = false
        var currentStep = 0
        var lastDialogText = ""
        var seenInitialLoadingDialog = false

        // ── Overlay helper ────────────────────────────────────────────────
        /** Posts a PROMPT entry to the live overlay (no-op if overlay not running). */
        private fun logPrompt(text: String) {
            UssdOverlayService.addLog("PROMPT", text)
        }

        /** Posts an INPUT entry to the live overlay. Masks PIN values. */
        private fun logInput(text: String, mask: Boolean = false) {
            UssdOverlayService.addLog("INPUT", if (mask) "•".repeat(text.length) else text)
        }
    }

    enum class UssdTask { NONE, BALANCE_CHECK, SEND_MONEY, CASH_OUT }

    override fun onServiceConnected() {
        instance = this
        Log.d(TAG, "✅ Accessibility Service Connected")
    }

    override fun onInterrupt() {
        Log.d(TAG, "⚠️ Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isRunning || event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val root = rootInActiveWindow ?: return
        val dialogText = extractText(root).trim()

        if (dialogText.isEmpty()) return

        val hasInputField = findEditText(root) != null
        val isResultStep = currentStep == getResultStep()

        // Ignore transient loading dialogs before first actionable prompt
        if (!seenInitialLoadingDialog && !hasInputField && !isResultStep) {
            seenInitialLoadingDialog = true
            Log.d(TAG, "⏳ Initial loading dialog detected: $dialogText")
            return
        }

        // If loading was shown, first actionable dialog must have an input field
        if (seenInitialLoadingDialog && currentStep == 0 && !hasInputField) {
            failSession(dialogText)
            return
        }

        if (!hasInputField && !isResultStep) {
            Log.d(TAG, "⏭️ Skipping dialog (no input field, not result step): $dialogText")
            return
        }

        if (dialogText == lastDialogText) return
        lastDialogText = dialogText

        Log.d(TAG, "📱 New dialog [step=$currentStep, hasInput=$hasInputField]:\n$dialogText")

        // Log the USSD prompt to the overlay
        logPrompt(dialogText)

        when (currentTask) {
            UssdTask.BALANCE_CHECK -> handleBalanceCheck(dialogText, hasInputField)
            UssdTask.SEND_MONEY    -> handleSendMoney(dialogText, hasInputField)
            UssdTask.CASH_OUT      -> handleCashOut(dialogText, hasInputField)
            UssdTask.NONE -> {}
        }
    }

    private fun getResultStep(): Int = when (currentTask) {
        UssdTask.BALANCE_CHECK -> 4
        UssdTask.SEND_MONEY    -> 6
        UssdTask.CASH_OUT      -> 6
        UssdTask.NONE          -> -1
    }

    // ─────────────────────────────────────────────────────────────────────
    //  TASK: Balance Check
    // ─────────────────────────────────────────────────────────────────────
    private var balanceSentContinue = false

    private fun handleBalanceCheck(dialogText: String, hasInputField: Boolean) {
        when (currentStep) {
            0 -> {
                val hasContinuePrompt = dialogText.contains("Do you want to continue", ignoreCase = true)
                val reply = if (hasContinuePrompt) { balanceSentContinue = true; "2" }
                else { balanceSentContinue = false; "9" }
                Log.d(TAG, "Step 0 → sending '$reply'")
                logInput(reply)
                typeAndSend(reply)
                currentStep += if (reply == "2") 1 else 2
            }
            1 -> { Log.d(TAG, "Step 1 → sending '9'"); logInput("9"); typeAndSend("9"); currentStep++ }
            2 -> { Log.d(TAG, "Step 2 → sending '1'"); logInput("1"); typeAndSend("1"); currentStep++ }
            3 -> { Log.d(TAG, "Step 3 → sending PIN"); logInput(pin, mask = true); typeAndSend(pin); currentStep++ }
            4 -> {
                if (!hasInputField) {
                    Log.d(TAG, "Step 4 → Balance check failed (no input on last step):\n$dialogText")
                    failSession(dialogText)
                    return
                }
                Log.d(TAG, "Step 4 → Final result:\n$dialogText")
                finishSession(dialogText)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  TASK: Send Money
    // ─────────────────────────────────────────────────────────────────────
    private fun handleSendMoney(dialogText: String, hasInputField: Boolean) {
        when (currentStep) {
            0 -> {
                val hasContinuePrompt = dialogText.contains("Do you want to continue", ignoreCase = true)
                val reply = if (hasContinuePrompt) "2" else "1"
                Log.d(TAG, "Step 0 → sending '$reply'")
                logInput(reply)
                typeAndSend(reply)
                currentStep += if (reply == "2") 1 else 2
            }
            1 -> { Log.d(TAG, "Step 1 → sending '1'"); logInput("1"); typeAndSend("1"); currentStep++ }
            2 -> { Log.d(TAG, "Step 2 → sending phoneNumber"); logInput(phoneNumber); typeAndSend(phoneNumber); currentStep++ }
            3 -> { Log.d(TAG, "Step 3 → sending amount"); logInput(amount); typeAndSend(amount); currentStep++ }
            4 -> { Log.d(TAG, "Step 4 → sending reference"); logInput(reference); typeAndSend(reference); currentStep++ }
            5 -> { Log.d(TAG, "Step 5 → sending PIN"); logInput(pin, mask = true); typeAndSend(pin); currentStep++ }
            6 -> {
                if (hasInputField) {
                    Log.d(TAG, "Step 6 → Send money failed (input still present on last step):\n$dialogText")
                    failSession(dialogText)
                    return
                }
                Log.d(TAG, "Step 6 → Final result:\n$dialogText")
                finishSession(dialogText)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  TASK: Cash Out
    // ─────────────────────────────────────────────────────────────────────
    private fun handleCashOut(dialogText: String, hasInputField: Boolean) {
        when (currentStep) {
            0 -> {
                val hasContinuePrompt = dialogText.contains("Do you want to continue", ignoreCase = true)
                val reply = if (hasContinuePrompt) "2" else "5"
                Log.d(TAG, "Step 0 → sending '$reply'")
                logInput(reply)
                typeAndSend(reply)
                currentStep += if (reply == "2") 1 else 2
            }
            1 -> { Log.d(TAG, "Step 1 → sending '5'"); logInput("5"); typeAndSend("5"); currentStep++ }
            2 -> { Log.d(TAG, "Step 2 → sending '1'"); logInput("1"); typeAndSend("1"); currentStep++ }
            3 -> { Log.d(TAG, "Step 3 → sending phoneNumber"); logInput(phoneNumber); typeAndSend(phoneNumber); currentStep++ }
            4 -> { Log.d(TAG, "Step 4 → sending amount"); logInput(amount); typeAndSend(amount); currentStep++ }
            5 -> { Log.d(TAG, "Step 5 → sending PIN"); logInput(pin, mask = true); typeAndSend(pin); currentStep++ }
            6 -> {
                if (hasInputField) {
                    Log.d(TAG, "Step 6 → Cash out failed (input still present on last step):\n$dialogText")
                    failSession(dialogText)
                    return
                }
                Log.d(TAG, "Step 6 → Final result:\n$dialogText")
                finishSession(dialogText)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  typeAndSend
    // ─────────────────────────────────────────────────────────────────────
    private fun typeAndSend(text: String) {
        Handler(Looper.getMainLooper()).postDelayed({

            val freshRoot = rootInActiveWindow
            if (freshRoot == null) {
                Log.e(TAG, "❌ rootInActiveWindow null when typing '$text'")
                onError?.invoke("Lost dialog window when sending '$text'")
                return@postDelayed
            }

            val editField = findEditText(freshRoot)
            if (editField == null) {
                Log.e(TAG, "❌ No EditText found for '$text'")
                onError?.invoke("No input field found for '$text'")
                return@postDelayed
            }

            val args = Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text
                )
            }
            val typed = editField.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            Log.d(TAG, "⌨️ Typed '$text' → success=$typed")

            Handler(Looper.getMainLooper()).postDelayed({
                val rootForClick = rootInActiveWindow ?: return@postDelayed
                val clicked = clickButton(
                    rootForClick,
                    listOf("Send", "SEND", "OK", "Ok", "Reply", "Proceed")
                )
                Log.d(TAG, "🖱️ Send clicked → $clicked")
            }, 600)

        }, 600)
    }

    private fun finishSession(dialogText: String) {
        cleanupSessionState()

        Handler(Looper.getMainLooper()).postDelayed({
            val root = rootInActiveWindow ?: return@postDelayed
            clickButton(root, listOf("OK", "Done", "Close", "Cancel", "Dismiss"))
        }, 500)

        Handler(Looper.getMainLooper()).post {
            onResult?.invoke(dialogText)
        }
    }

    private fun failSession(errorText: String) {
        Log.e(TAG, "❌ Session failed:\n$errorText")
        cleanupSessionState()

        Handler(Looper.getMainLooper()).postDelayed({
            val root = rootInActiveWindow ?: return@postDelayed
            clickButton(root, listOf("OK", "Done", "Close", "Cancel", "Dismiss"))
        }, 500)

        Handler(Looper.getMainLooper()).post {
            onError?.invoke(errorText)
        }
    }

    private fun cleanupSessionState() {
        isRunning = false
        currentStep = 0
        lastDialogText = ""
        seenInitialLoadingDialog = false
        balanceSentContinue = false
        phoneNumber = ""
        amount = ""
        reference = ""
    }

    private fun clickButton(root: AccessibilityNodeInfo, labels: List<String>): Boolean {
        val exactMatch = findNodeWithExactText(root, labels)
        if (exactMatch != null) {
            exactMatch.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            Log.d(TAG, "🖱️ Exact-matched and clicked: '${exactMatch.text}'")
            return true
        }
        val clickableFallback = findClickableNodeWithExactText(root, labels)
        if (clickableFallback != null) {
            clickableFallback.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            Log.d(TAG, "🖱️ Clickable-fallback clicked: '${clickableFallback.text}'")
            return true
        }
        Log.w(TAG, "⚠️ No button matched: $labels")
        return false
    }

    private fun findNodeWithExactText(
        node: AccessibilityNodeInfo,
        labels: List<String>
    ): AccessibilityNodeInfo? {
        val nodeText = node.text?.toString()?.trim() ?: ""
        if (labels.any { it.equals(nodeText, ignoreCase = true) }) return node
        for (i in 0 until node.childCount) {
            val found = node.getChild(i)?.let { findNodeWithExactText(it, labels) }
            if (found != null) return found
        }
        return null
    }

    private fun findClickableNodeWithExactText(
        node: AccessibilityNodeInfo,
        labels: List<String>
    ): AccessibilityNodeInfo? {
        val nodeText = node.text?.toString()?.trim() ?: ""
        if (node.isClickable && labels.any { it.equals(nodeText, ignoreCase = true) }) return node
        for (i in 0 until node.childCount) {
            val found = node.getChild(i)?.let { findClickableNodeWithExactText(it, labels) }
            if (found != null) return found
        }
        return null
    }

    private fun extractText(node: AccessibilityNodeInfo): String {
        val lines = linkedSetOf<String>()
        collectText(node, lines)
        return lines.joinToString("\n")
    }

    private fun collectText(node: AccessibilityNodeInfo, lines: LinkedHashSet<String>) {
        val text = node.text?.toString()?.trim().orEmpty()
        if (text.isNotEmpty() && shouldKeepDialogText(node, text)) {
            lines.add(text)
        }

        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { collectText(it, lines) }
        }
    }

    private fun shouldKeepDialogText(node: AccessibilityNodeInfo, text: String): Boolean {
        val actionTexts = setOf(
            "send", "ok", "reply", "proceed", "done", "close", "cancel", "dismiss", "yes", "no", "back"
        )

        if (actionTexts.contains(text.lowercase())) return false

        val className = node.className?.toString().orEmpty()
        if (className.contains("Button", ignoreCase = true) && text.length <= 20) return false

        return true
    }

    private fun findEditText(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.className?.contains("EditText") == true && node.isEnabled) return node
        for (i in 0 until node.childCount) {
            val found = node.getChild(i)?.let { findEditText(it) }
            if (found != null) return found
        }
        return null
    }
}