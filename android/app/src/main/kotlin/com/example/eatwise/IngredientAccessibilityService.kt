package com.example.eatwise

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

/**
 * Accessibility Service that reads on-screen text to detect ingredients
 */
class IngredientAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "EatWiseAccessibility"
        var instance: IngredientAccessibilityService? = null
        var isScanning = false
    }

    // Keyword anchors to detect ingredient sections
    private val ingredientAnchors = listOf(
        "ingredients:", "ingredients", "contains:", "contains",
        "composition:", "composition", "made with", "made from", 
        "contents:", "contents", "ingredients list",
        // Hindi/Indian variants
        "सामग्री", "घटक"
    )

    // Stop words to end extraction
    private val stopKeywords = listOf(
        "allergen", "allergy", "allergy advice", "storage", "store in",
        "nutritional", "nutrition facts", "nutrition information",
        "directions", "best before", "expiry", "exp date",
        "manufactured", "packed by", "marketed by", "fssai",
        "net weight", "net wt", "net qty", "serving size", 
        "how to use", "customer care", "disclaimer", "warning"
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (!isScanning) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                // Process screen when content changes
                processScreen()
            }
        }
    }

    /**
     * Process current screen content
     */
    fun processScreen() {
        Log.d(TAG, "Starting screen scan...")
        
        val root = rootInActiveWindow ?: run {
            Log.d(TAG, "No active window available")
            IngredientScanner.sendStatus("No screen content available. Make sure you're on a product page.")
            isScanning = false
            return
        }
        
        val collectedText = StringBuilder()
        
        try {
            // Also try to get text from all windows (for overlays, dialogs, etc.)
            windows?.forEach { window ->
                try {
                    window.root?.let { windowRoot ->
                        traverseNode(windowRoot, collectedText)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing window: ${e.message}")
                }
            }
            
            // Also traverse the main root
            traverseNode(root, collectedText)
        } catch (e: Exception) {
            Log.e(TAG, "Error during traversal: ${e.message}")
        }

        val fullText = collectedText.toString()
        Log.d(TAG, "Collected ${fullText.length} characters from screen")
        Log.d(TAG, "First 500 chars: ${fullText.take(500)}")
        
        val ingredientBlock = extractIngredientBlock(fullText)

        if (ingredientBlock.isNotEmpty() && ingredientBlock.length > 20) {
            Log.d(TAG, "Found ingredients: ${ingredientBlock.take(200)}...")
            IngredientScanner.sendToFlutter(ingredientBlock)
        } else if (fullText.length > 100) {
            // If we have substantial text but no ingredients anchor, send it for direct parsing
            Log.d(TAG, "No anchor found, sending full text for analysis")
            IngredientScanner.sendToFlutter(fullText)
        } else {
            Log.d(TAG, "No ingredients found on this screen (collected ${fullText.length} chars)")
            IngredientScanner.sendStatus("No ingredient list found. Scroll to show ingredients and try again.")
        }
        
        // Always reset scanning state to allow next scan
        isScanning = false

        try {
            root.recycle()
        } catch (e: Exception) {
            // Ignore recycle errors
        }
    }

    /**
     * Recursively traverse accessibility node tree - captures ALL text
     */
    private fun traverseNode(node: AccessibilityNodeInfo?, builder: StringBuilder, depth: Int = 0) {
        if (node == null || depth > 50) return  // Prevent infinite recursion

        // Get text content from multiple sources
        node.text?.let { text ->
            val str = text.toString().trim()
            if (str.isNotEmpty() && str.length > 1) {
                builder.append(str).append(" ")
            }
        }

        // Get content description (for images/icons with alt text)
        node.contentDescription?.let { desc ->
            val str = desc.toString().trim()
            if (str.isNotEmpty() && str.length > 1) {
                builder.append(str).append(" ")
            }
        }
        
        // Get hint text (sometimes contains useful info)
        node.hintText?.let { hint ->
            val str = hint.toString().trim()
            if (str.isNotEmpty() && str.length > 1) {
                builder.append(str).append(" ")
            }
        }
        
        // Get tooltip text
        node.tooltipText?.let { tooltip ->
            val str = tooltip.toString().trim()
            if (str.isNotEmpty() && str.length > 1) {
                builder.append(str).append(" ")
            }
        }

        // Traverse children
        for (i in 0 until node.childCount) {
            try {
                val child = node.getChild(i)
                if (child != null) {
                    traverseNode(child, builder, depth + 1)
                    try {
                        child.recycle()
                    } catch (e: Exception) {
                        // Ignore recycle errors
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error traversing child node: ${e.message}")
            }
        }
    }

    /**
     * Extract ingredient block from full screen text
     */
    private fun extractIngredientBlock(text: String): String {
        val lowerText = text.lowercase()

        // Find ingredient anchor
        var startIndex = -1
        for (anchor in ingredientAnchors) {
            val idx = lowerText.indexOf(anchor)
            if (idx != -1) {
                startIndex = idx
                break
            }
        }

        if (startIndex == -1) {
            // No anchor found - return empty (or could return full text for analysis)
            return ""
        }

        // Find end of ingredient section
        var endIndex = text.length
        for (stop in stopKeywords) {
            val idx = lowerText.indexOf(stop, startIndex + 10)
            if (idx != -1 && idx < endIndex) {
                endIndex = idx
            }
        }

        // Limit to reasonable length
        endIndex = minOf(endIndex, startIndex + 2000)

        return text.substring(startIndex, endIndex).trim()
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        instance = null
        isScanning = false
        super.onDestroy()
        Log.d(TAG, "Accessibility Service Destroyed")
    }
}
