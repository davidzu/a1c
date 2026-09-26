package com.a1c.app.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * The outbox: doses logged while offline, waiting to be sent to the API.
 *
 * Stored as a JSON array in DataStore (Preferences). Kept deliberately tiny —
 * a few fields per dose, no Room, per the project contract.
 */
@Serializable
data class PendingDose(
    val uuid: String,
    val units: Int,
    val kind: String,
    val takenAt: String, // ISO8601 with offset, e.g. 2026-09-26T08:15:00-06:00
)

private val Context.outboxStore by preferencesDataStore(name = "a1c_outbox")

class Outbox(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true }
    private val key = stringPreferencesKey("pending_doses")

    /** Emits the current pending list on every change. */
    val pending: Flow<List<PendingDose>> = context.outboxStore.data.map { prefs ->
        prefs[key]?.let { decode(it) } ?: emptyList()
    }

    suspend fun enqueue(dose: PendingDose) {
        context.outboxStore.edit { prefs ->
            val current = prefs[key]?.let { decode(it) } ?: emptyList()
            // Never queue the same uuid twice (defensive; uuids are fresh).
            if (current.none { it.uuid == dose.uuid }) {
                prefs[key] = encode(current + dose)
            }
        }
    }

    /** Removes every dose whose uuid is in the given list. */
    suspend fun removeAll(uuids: List<String>) {
        if (uuids.isEmpty()) return
        context.outboxStore.edit { prefs ->
            val current = prefs[key]?.let { decode(it) } ?: emptyList()
            val sent = uuids.toSet()
            prefs[key] = encode(current.filterNot { it.uuid in sent })
        }
    }

    suspend fun snapshot(): List<PendingDose> = pending.first()

    private fun encode(list: List<PendingDose>): String =
        json.encodeToString(ListSerializer(PendingDose.serializer()), list)

    private fun decode(raw: String): List<PendingDose> = runCatching {
        json.decodeFromString(ListSerializer(PendingDose.serializer()), raw)
    }.getOrDefault(emptyList())
}
