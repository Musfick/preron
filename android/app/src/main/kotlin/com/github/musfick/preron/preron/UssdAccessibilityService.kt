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

        if (!hasInputField && !isResultStep) {
            Log.d(TAG, "⏭️ Skipping dialog (no input field, not result step): $dialogText")
            return
        }

        if (dialogText == lastDialogText) return
        lastDialogText = dialogText

        Log.d(TAG, "📱 New dialog [step=$currentStep, hasInput=$hasInputField]:\n$dialogText")

        when (currentTask) {
            UssdTask.BALANCE_CHECK -> handleBalanceCheck(dialogText)
            UssdTask.SEND_MONEY   -> handleSendMoney(dialogText)
            UssdTask.CASH_OUT     -> handleCashOut(dialogText)
            UssdTask.NONE -> {}
        }
    }

    private fun getResultStep(): Int = when (currentTask) {
        UssdTask.BALANCE_CHECK -> 4
        UssdTask.SEND_MONEY    -> 6
        UssdTask.CASH_OUT      -> 5
        UssdTask.NONE          -> -1
    }

    // ─────────────────────────────────────────────────────────────────────
    //  TASK: Balance Check
    //
    //  *247# → Step 0 (continue? YES→"2" jump+1 / NO→"9" jump+2)
    //        → Step 1 → "9"
    //        → Step 2 → "1"
    //        → Step 3 → PIN
    //        → Step 4 → capture result
    // ─────────────────────────────────────────────────────────────────────
    private var balanceSentContinue = false

    private fun handleBalanceCheck(dialogText: String) {
        when (currentStep) {
            0 -> {
                val hasContinuePrompt = dialogText.contains("Do you want to continue", ignoreCase = true)
                val reply = if (hasContinuePrompt) { balanceSentContinue = true; "2" }
                else { balanceSentContinue = false; "9" }
                Log.d(TAG, "Step 0 → sending '$reply'")
                typeAndSend(reply)
                currentStep += if (reply == "2") 1 else 2
            }
            1 -> { Log.d(TAG, "Step 1 → sending '9'"); typeAndSend("9"); currentStep++ }
            2 -> { Log.d(TAG, "Step 2 → sending '1'"); typeAndSend("1"); currentStep++ }
            3 -> { Log.d(TAG, "Step 3 → sending PIN"); typeAndSend(pin); currentStep++ }
            4 -> { Log.d(TAG, "Step 4 → Final result:\n$dialogText"); finishSession(dialogText) }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  TASK: Send Money
    //
    //  *247# → Step 0 (continue? YES→"2" jump+1 / NO→"1" jump+2)
    //        → Step 1 → "1"
    //        → Step 2 → phoneNumber
    //        → Step 3 → amount
    //        → Step 4 → reference
    //        → Step 5 → PIN
    //        → Step 6 → capture result
    // ─────────────────────────────────────────────────────────────────────
    private fun handleSendMoney(dialogText: String) {
        when (currentStep) {
            0 -> {
                val hasContinuePrompt = dialogText.contains("Do you want to continue", ignoreCase = true)
                val reply = if (hasContinuePrompt) "2" else "1"
                Log.d(TAG, "Step 0 → sending '$reply'")
                typeAndSend(reply)
                currentStep += if (reply == "2") 1 else 2
            }
            1 -> { Log.d(TAG, "Step 1 → sending '1'"); typeAndSend("1"); currentStep++ }
            2 -> { Log.d(TAG, "Step 2 → sending phoneNumber"); typeAndSend(phoneNumber); currentStep++ }
            3 -> { Log.d(TAG, "Step 3 → sending amount"); typeAndSend(amount); currentStep++ }
            4 -> { Log.d(TAG, "Step 4 → sending reference"); typeAndSend(reference); currentStep++ }
            5 -> { Log.d(TAG, "Step 5 → sending PIN"); typeAndSend(pin); currentStep++ }
            6 -> { Log.d(TAG, "Step 6 → Final result:\n$dialogText"); finishSession(dialogText) }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  TASK: Cash Out
    //
    //  *247# → Step 0 (continue? YES→"2" jump+1 / NO→"5" jump+2)
    //        → Step 1 → "5"
    //        → Step 2 → "1"
    //        → Step 3 → phoneNumber
    //        → Step 4 → amount  (note: comment in spec labels this Step 3 — we use Step 4)
    //        → Step 5 (PIN) → captured at Step 5 result
    //  Wait — per spec the result is captured at Step 5, PIN is sent at Step 4.
    //  Corrected mapping:
    //        → Step 3 → phoneNumber
    //        → Step 4 → amount
    //        → Step 5 (no input) → capture result  ← getResultStep() = 5
    //  But PIN must be sent before the result dialog. Re-reading spec:
    //        → Step 3 → phoneNumber
    //        → Step 4 → amount
    //        → Step 5 → PIN       (but spec says "Step 4 → send PIN"?)
    //  Using the literal step order from the spec comment:
    //        Step 3 → phoneNumber, Step 3(b) → amount, Step 4 → PIN, Step 5 → result
    //  Renumbered cleanly:
    //        Step 3 → phoneNumber
    //        Step 4 → amount
    //        Step 5 → PIN         ← last input step
    //        getResultStep() = 6  ← final result dialog (no input)
    // ─────────────────────────────────────────────────────────────────────
    private fun handleCashOut(dialogText: String) {
        when (currentStep) {
            0 -> {
                val hasContinuePrompt = dialogText.contains("Do you want to continue", ignoreCase = true)
                val reply = if (hasContinuePrompt) "2" else "5"
                Log.d(TAG, "Step 0 → sending '$reply'")
                typeAndSend(reply)
                currentStep += if (reply == "2") 1 else 2
            }
            1 -> { Log.d(TAG, "Step 1 → sending '5'"); typeAndSend("5"); currentStep++ }
            2 -> { Log.d(TAG, "Step 2 → sending '1'"); typeAndSend("1"); currentStep++ }
            3 -> { Log.d(TAG, "Step 3 → sending phoneNumber"); typeAndSend(phoneNumber); currentStep++ }
            4 -> { Log.d(TAG, "Step 4 → sending amount"); typeAndSend(amount); currentStep++ }
            5 -> { Log.d(TAG, "Step 5 → sending PIN"); typeAndSend(pin); currentStep++ }
            6 -> { Log.d(TAG, "Step 6 → Final result:\n$dialogText"); finishSession(dialogText) }
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
        isRunning = false
        currentStep = 0
        lastDialogText = ""
        balanceSentContinue = false
        phoneNumber = ""
        amount = ""
        reference = ""

        Handler(Looper.getMainLooper()).postDelayed({
            val root = rootInActiveWindow ?: return@postDelayed
            clickButton(root, listOf("OK", "Done", "Close", "Cancel", "Dismiss"))
        }, 500)

        Handler(Looper.getMainLooper()).post {
            onResult?.invoke(dialogText)
        }
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
        val sb = StringBuilder()
        collectText(node, sb)
        return sb.toString()
    }

    private fun collectText(node: AccessibilityNodeInfo, sb: StringBuilder) {
        if (!node.text.isNullOrEmpty()) sb.append(node.text).append("\n")
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { collectText(it, sb) }
        }
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