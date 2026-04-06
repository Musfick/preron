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
        var onResult: ((String) -> Unit)? = null
        var onError: ((String) -> Unit)? = null
        var isRunning = false
        var currentStep = 0
        var lastDialogText = ""
    }

    enum class UssdTask { NONE, BALANCE_CHECK }

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

        // ── KEY FIX: Skip any dialog that has NO input field ─────────────
        // Loading dialogs / info-only dialogs won't have an EditText.
        // The RESULT dialog at the end also has no EditText — but we handle
        // that separately at step 4 (the last step).
        val hasInputField = findEditText(root) != null
        val isResultStep = currentStep == getResultStep()

        if (!hasInputField && !isResultStep) {
            Log.d(TAG, "⏭️ Skipping dialog (no input field, not result step): $dialogText")
            return
        }

        // Debounce: ignore same dialog text firing twice
        if (dialogText == lastDialogText) return
        lastDialogText = dialogText

        Log.d(TAG, "📱 New dialog [step=$currentStep, hasInput=$hasInputField]:\n$dialogText")

        when (currentTask) {
            UssdTask.BALANCE_CHECK -> handleBalanceCheck(dialogText)
            UssdTask.NONE -> {}
        }
    }

    // Returns which step number is the final result step for current task
    private fun getResultStep(): Int = when (currentTask) {
        UssdTask.BALANCE_CHECK -> 4
        UssdTask.NONE -> -1
    }

    // ─────────────────────────────────────────────────────────────────────
    //  TASK 1 — Balance Check
    //
    //  Dial *247#
    //    ↓ [loading dialog — NO input] → SKIPPED automatically
    //    ↓ [first real dialog with input field]
    //  Step 0 → contains "Do you want to continue?"
    //             YES → send "2"
    //             NO  → send "9"
    //    ↓ [new dialog with input]
    //  Step 1 → send "9"
    //    ↓ [new dialog with input]
    //  Step 2 → send "1"
    //    ↓ [new dialog with input]
    //  Step 3 → send PIN
    //    ↓ [final result dialog — NO input] → captured at step 4
    //  Step 4 → capture text → return to Flutter
    // ─────────────────────────────────────────────────────────────────────
    private var balanceSentContinue = false

    private fun handleBalanceCheck(dialogText: String) {
        when (currentStep) {

            0 -> {
                val hasContinuePrompt = dialogText.contains(
                    "Do you want to continue", ignoreCase = true
                )
                val reply = if (hasContinuePrompt) {
                    balanceSentContinue = true
                    "2"
                } else {
                    balanceSentContinue = false
                    "9"
                }
                Log.d(TAG, "Step 0 → sending '$reply'")
                typeAndSend(reply)
                if(reply == "2"){
                    currentStep = currentStep + 1
                }else{
                    currentStep = currentStep + 2
                }

            }

            1 -> {
                Log.d(TAG, "Step 1 → sending '9'")
                typeAndSend("9")
                currentStep++
            }

            2 -> {
                Log.d(TAG, "Step 2 → sending '1'")
                typeAndSend("1")
                currentStep++
            }

            3 -> {
                Log.d(TAG, "Step 3 → sending PIN")
                typeAndSend(pin)
                currentStep++
                // After PIN is sent, next dialog will have NO input field
                // (it's the result). The skip guard above will allow it
                // through because currentStep will be 4 == getResultStep()
            }

            4 -> {
                Log.d(TAG, "Step 4 → Final result:\n$dialogText")
                finishSession(dialogText)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  typeAndSend — grabs fresh rootInActiveWindow at execution time
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

        Handler(Looper.getMainLooper()).postDelayed({
            val root = rootInActiveWindow ?: return@postDelayed
            clickButton(root, listOf("OK", "Done", "Close", "Cancel", "Dismiss"))
        }, 500)

        Handler(Looper.getMainLooper()).post {
            onResult?.invoke(dialogText)
        }
    }

    private fun clickButton(root: AccessibilityNodeInfo, labels: List<String>): Boolean {
        // ── Strategy 1: exact text match by traversing all nodes ─────────────
        // findAccessibilityNodeInfosByText() does CONTAINS match — dangerous
        // when menu items contain words like "Send". We traverse manually
        // and compare trimmed text exactly.
        val exactMatch = findNodeWithExactText(root, labels)
        if (exactMatch != null) {
            exactMatch.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            Log.d(TAG, "🖱️ Exact-matched and clicked: '${exactMatch.text}'")
            return true
        }

        // ── Strategy 2: fallback — find a clickable node whose text matches ──
        // (some dialogs wrap the button text in a parent clickable view)
        val clickableFallback = findClickableNodeWithExactText(root, labels)
        if (clickableFallback != null) {
            clickableFallback.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            Log.d(TAG, "🖱️ Clickable-fallback clicked: '${clickableFallback.text}'")
            return true
        }

        Log.w(TAG, "⚠️ No button matched: $labels")
        return false
    }

    /** Traverses the tree and returns the first node whose trimmed text
     *  EXACTLY equals one of the target labels (case-insensitive). */
    private fun findNodeWithExactText(
        node: AccessibilityNodeInfo,
        labels: List<String>
    ): AccessibilityNodeInfo? {
        val nodeText = node.text?.toString()?.trim() ?: ""
        if (labels.any { it.equals(nodeText, ignoreCase = true) }) {
            return node
        }
        for (i in 0 until node.childCount) {
            val found = node.getChild(i)?.let { findNodeWithExactText(it, labels) }
            if (found != null) return found
        }
        return null
    }

    /** Same as above but only returns nodes that are also clickable.
     *  Useful when the text node itself isn't clickable but its parent is. */
    private fun findClickableNodeWithExactText(
        node: AccessibilityNodeInfo,
        labels: List<String>
    ): AccessibilityNodeInfo? {
        val nodeText = node.text?.toString()?.trim() ?: ""
        if (node.isClickable && labels.any { it.equals(nodeText, ignoreCase = true) }) {
            return node
        }
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