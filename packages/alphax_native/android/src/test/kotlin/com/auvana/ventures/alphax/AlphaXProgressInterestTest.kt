package com.auvana.ventures.alphax

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AlphaXProgressInterestTest {
    @Test
    fun noObserversSuppressBothDirections() {
        val interest = AlphaXProgressInterest.from(emptyMap())

        assertFalse(interest.isRequested("download"))
        assertFalse(interest.isRequested("upload"))
    }

    @Test
    fun directionsRemainIndependentPerOperation() {
        val downloadOnly = AlphaXProgressInterest.from(
            mapOf("downloadProgressRequested" to true),
        )
        val uploadOnly = AlphaXProgressInterest.from(
            mapOf("uploadProgressRequested" to true),
        )

        assertTrue(downloadOnly.isRequested("download"))
        assertFalse(downloadOnly.isRequested("upload"))
        assertFalse(uploadOnly.isRequested("download"))
        assertTrue(uploadOnly.isRequested("upload"))
    }

    @Test
    fun unknownDirectionsAreSuppressed() {
        val interest = AlphaXProgressInterest.from(
            mapOf(
                "downloadProgressRequested" to true,
                "uploadProgressRequested" to true,
            ),
        )

        assertFalse(interest.isRequested("other"))
    }
}
