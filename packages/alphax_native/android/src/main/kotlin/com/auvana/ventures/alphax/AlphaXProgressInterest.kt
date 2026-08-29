package com.auvana.ventures.alphax

/** Operation-local progress interest; never shared between requests. */
internal data class AlphaXProgressInterest(
    val downloadRequested: Boolean,
    val uploadRequested: Boolean,
) {
    fun isRequested(direction: String): Boolean = when (direction) {
        "download" -> downloadRequested
        "upload" -> uploadRequested
        else -> false
    }

    companion object {
        fun from(arguments: Map<String, Any?>): AlphaXProgressInterest = AlphaXProgressInterest(
            downloadRequested = arguments["downloadProgressRequested"] == true,
            uploadRequested = arguments["uploadProgressRequested"] == true,
        )
    }
}
