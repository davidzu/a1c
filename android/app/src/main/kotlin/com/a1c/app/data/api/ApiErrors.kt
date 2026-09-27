package com.a1c.app.data.api

import retrofit2.HttpException

/**
 * Turns API failures into human sentences.
 *
 * The backend always renders errors as
 * `{ "error": { "code": ..., "message": ..., "field": ... } }`, so a 4xx
 * response carries a message meant for a human (e.g. "Units must be greater
 * than 0"). Anything else (5xx, offline, timeouts) falls back to a generic
 * friendly line.
 */
object ApiErrors {

    /** Human message for a dose-logging failure. */
    fun logDose(e: Exception): String = when (e) {
        is HttpException -> humanMessage(e) ?: "Could not save the dose. Try again."
        else -> null
    } ?: "Can't reach the A1C API — dose saved offline, will sync later."

    /** Human message for a settings-save failure. */
    fun saveSettings(e: Exception): String = when (e) {
        is HttpException -> humanMessage(e) ?: "The server refused the change."
        else -> null
    } ?: "Can't reach the A1C API. Change not saved."

    private fun humanMessage(e: HttpException): String? {
        if (e.code() !in 400..499) return null
        val body = e.response()?.errorBody()?.string() ?: return null
        return runCatching {
            ApiErrorResponseDtoSerializer.decode(body).error.message
        }.getOrNull()
    }
}

/** Minimal JSON reader for the error envelope, tolerant of unknown fields. */
private object ApiErrorResponseDtoSerializer {
    private val json = kotlinx.serialization.json.Json { ignoreUnknownKeys = true }

    fun decode(raw: String): ApiErrorResponseDto =
        json.decodeFromString(ApiErrorResponseDto.serializer(), raw)
}
