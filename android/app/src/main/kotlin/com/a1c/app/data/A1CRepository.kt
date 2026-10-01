package com.a1c.app.data

import com.a1c.app.data.api.A1CApi
import com.a1c.app.data.api.ActivityDto
import com.a1c.app.data.api.ApiErrors
import com.a1c.app.data.api.DailyTotalDto
import com.a1c.app.data.api.DayDto
import com.a1c.app.data.api.DoseDto
import com.a1c.app.data.api.GlucoseReadingDto
import com.a1c.app.data.api.NewDoseDto
import com.a1c.app.data.api.NutritionDto
import com.a1c.app.data.api.SettingsDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.time.Instant
import java.time.OffsetDateTime
import java.time.temporal.ChronoUnit
import java.util.UUID

sealed interface DoseLogResult {
    /** Sent to the API and confirmed. */
    data object Success : DoseLogResult

    /** Stored in the local outbox; will sync on next open/resume. */
    data object Offline : DoseLogResult

    /** Rejected — the dose was NOT saved anywhere. */
    data class Failure(val message: String) : DoseLogResult
}

class A1CRepository(
    private val api: A1CApi,
    private val outbox: Outbox,
    private val health: HealthConnectReader? = null,
) {

    private val _log = MutableStateFlow(LogData.empty())
    val log: StateFlow<LogData> = _log.asStateFlow()

    suspend fun refresh() {
        syncOutbox()
        syncHealthConnect()
        fetch()
    }

    /**
     * Local-first save: enqueue immediately (durable), update the UI
     * optimistically, then try the network. On success the entry leaves the
     * outbox; on network failure it stays queued and syncs later.
     */
    suspend fun logDose(units: Int, kind: String): DoseLogResult {
        val takenAt = OffsetDateTime.now().format(java.time.format.DateTimeFormatter.ISO_OFFSET_DATE_TIME)
        val clientId = UUID.randomUUID().toString()
        val pending = PendingDose(uuid = clientId, units = units, kind = kind, takenAt = takenAt)

        outbox.enqueue(pending)
        _log.update { it.mergedWith(listOf(pending)).copy(pendingCount = it.pendingCount + 1) }

        return try {
            api.createDose(NewDoseDto(units = units, kind = kind, takenAt = takenAt, clientId = clientId))
            outbox.removeAll(listOf(clientId))
            _log.update { it.copy(pendingCount = (it.pendingCount - 1).coerceAtLeast(0)) }
            fetch()
            DoseLogResult.Success
        } catch (e: Exception) {
            if (e is retrofit2.HttpException && e.code() in 400..499 && e.code() != 408) {
                // Server actively rejected it (bad units/kind). Not an offline
                // case — drop from the outbox so it can't poison the queue.
                outbox.removeAll(listOf(clientId))
                _log.update { it.copy(pendingCount = (it.pendingCount - 1).coerceAtLeast(0)) }
                DoseLogResult.Failure(ApiErrors.logDose(e))
            } else {
                DoseLogResult.Offline
            }
        }
    }

    suspend fun saveSettings(settings: SettingsDto): DoseLogResult = try {
        val updated = api.updateSettings(settings).settings
        _log.update { it.copy(settings = updated) }
        DoseLogResult.Success
    } catch (e: Exception) {
        DoseLogResult.Failure(ApiErrors.saveSettings(e))
    }

    /** POST every queued dose (idempotent via client_id), then refresh. */
    private suspend fun syncOutbox() {
        val pending = outbox.snapshot()
        if (pending.isEmpty()) return

        val sent = mutableListOf<String>()
        for (dose in pending) {
            try {
                api.createDose(
                    NewDoseDto(units = dose.units, kind = dose.kind, takenAt = dose.takenAt, clientId = dose.uuid)
                )
                sent += dose.uuid
            } catch (_: Exception) {
                break // offline or server down — keep the rest queued
            }
        }
        if (sent.isNotEmpty()) {
            outbox.removeAll(sent)
            fetch()
        }
    }

    /**
     * Health Connect pipe (ADR-003): surface the availability state, then
     * read-and-POST everything in the window. Stateless — the server dedupes
     * on `hc:<metadata-id>`, so re-reading is free. Failures never block
     * dose logging; the data stays on the phone until a later refresh.
     */
    private suspend fun syncHealthConnect() {
        val reader = health ?: return
        val state = runCatching { reader.status() }.getOrDefault(HealthConnectState.Unavailable)
        _log.update { it.copy(healthConnect = state) }
        if (state != HealthConnectState.Ready) return

        val since = Instant.now().minus(HealthConnectReader.READ_WINDOW_DAYS, ChronoUnit.DAYS)
        val result = reader.readSince(since)
        _log.update { it.copy(healthRead = result) }
        if (result.uploads.isEmpty) return

        try {
            if (result.uploads.activities.isNotEmpty()) {
                api.createActivities(result.uploads.activities)
            }
            if (result.uploads.nutrition.isNotEmpty()) {
                api.createNutrition(result.uploads.nutrition)
            }
            _log.update { it.copy(healthRead = result.copy(error = null)) }
        } catch (e: Exception) {
            val msg = when {
                e is retrofit2.HttpException && e.code() in 400..499 ->
                    com.a1c.app.data.api.ApiErrors.saveSettings(e) // same envelope parser
                else -> "upload offline (kept for retry)"
            }
            _log.update { it.copy(healthRead = result.copy(error = msg)) }
        }
    }

    /** Fetch server state and merge any still-pending doses for display. */
    private suspend fun fetch() {
        try {
            val doses = api.doses()
            val settings = try {
                api.settings().settings
            } catch (_: Exception) {
                null
            }
            val glucose = try {
                api.glucose(GLUCOSE_HOURS).glucose
            } catch (_: Exception) {
                _log.value.glucose
            }
            val days = try {
                api.days(DAYS).days
            } catch (_: Exception) {
                _log.value.days
            }
            val activities = try {
                api.activities(GLUCOSE_HOURS).activities
            } catch (_: Exception) {
                _log.value.activities
            }
            val nutrition = try {
                api.nutrition(GLUCOSE_HOURS).nutrition
            } catch (_: Exception) {
                _log.value.nutrition
            }
            val pending = outbox.snapshot()
            _log.update {
                doses.let { fetched ->
                    LogData(
                        doses = fetched.doses,
                        dailyTotals = fetched.dailyTotals,
                        settings = settings ?: it.settings,
                        pendingCount = pending.size,
                        loadError = null,
                        glucose = glucose,
                        days = days,
                        activities = activities,
                        nutrition = nutrition,
                        healthConnect = it.healthConnect,
                        healthRead = it.healthRead,
                    ).mergedWith(pending)
                }
            }
        } catch (e: Exception) {
            // Only a total failure to reach the API counts as a load error.
            // A settings failure alone falls back to the last known names.
            _log.update {
                it.copy(
                    loadError = if (e is retrofit2.HttpException) {
                        "Server error (${e.code()})"
                    } else {
                        "Can't reach the A1See API"
                    },
                )
            }
        }
    }

    companion object {
        const val GLUCOSE_HOURS = 24
        const val DAYS = 14
    }
}

data class LogData(
    val doses: List<DoseDto>,
    val dailyTotals: List<DailyTotalDto>,
    val settings: SettingsDto?,
    val pendingCount: Int = 0,
    /** Non-null when the last full load failed (API unreachable/server error). */
    val loadError: String? = null,
    /** CGM readings, ascending by time, last N hours. Empty until synced. */
    val glucose: List<GlucoseReadingDto> = emptyList(),
    /** Unified day rows (insulin/carbs/kcal/exercise) from /days, ascending. */
    val days: List<DayDto> = emptyList(),
    /** Exercise sessions, last 24 h — drawn as bands on the glucose curve. */
    val activities: List<ActivityDto> = emptyList(),
    /** Food entries, last 24 h — drawn as dots on the glucose curve. */
    val nutrition: List<NutritionDto> = emptyList(),
    /** Health Connect availability/permission state for the day bars. */
    val healthConnect: HealthConnectState = HealthConnectState.Unavailable,
    /** Last Health Connect read: counts or the error that stopped it. */
    val healthRead: HealthReadResult? = null,
) {
    /**
     * Merge pending (offline) doses into the display state. Display-only:
     * the server remains the source of truth once sync completes.
     */
    fun mergedWith(pending: List<PendingDose>): LogData {
        if (pending.isEmpty()) return this

        val pendingDoses = pending
            .sortedBy { it.takenAt }
            .map { p ->
                val instant = runCatching { OffsetDateTime.parse(p.takenAt).toInstant().toString() }
                    .getOrDefault(p.takenAt)
                DoseDto(id = -1, kind = p.kind, units = p.units, createdAt = instant, takenAt = p.takenAt, clientId = p.uuid)
            }
        val mergedDoses = doses + pendingDoses

        val byDate = dailyTotals.associateBy { it.date }.toMutableMap()
        pending.forEach { p ->
            val date = runCatching { OffsetDateTime.parse(p.takenAt).toLocalDate().toString() }
                .getOrDefault("")
            if (date.isEmpty()) return@forEach
            val current = byDate[date] ?: DailyTotalDto(date = date, fastUnits = 0, slowUnits = 0, totalUnits = 0)
            val updated = when (p.kind) {
                "fast" -> current.copy(fastUnits = current.fastUnits + p.units)
                else -> current.copy(slowUnits = current.slowUnits + p.units)
            }
            byDate[date] = updated.copy(totalUnits = updated.fastUnits + updated.slowUnits)
        }

        return copy(doses = mergedDoses, dailyTotals = byDate.values.sortedBy { it.date })
    }

    companion object {
        fun empty() = LogData(emptyList(), emptyList(), null, 0)
    }
}
