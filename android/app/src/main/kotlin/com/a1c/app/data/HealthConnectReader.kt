package com.a1c.app.data

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.MealType
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.a1c.app.data.api.NewActivityDto
import com.a1c.app.data.api.NewNutritionDto
import java.time.Instant
import java.time.temporal.ChronoUnit

/** Health Connect availability / permission state, surfaced to the UI. */
sealed interface HealthConnectState {
    /** No Health Connect provider on this device (or Android too old). */
    data object Unavailable : HealthConnectState

    /** Provider present but needs a Play Store update first. */
    data object UpdateRequired : HealthConnectState

    /** Ready, but the user hasn't granted read access yet. */
    data object NeedsPermissions : HealthConnectState

    /** Ready and readable. */
    data object Ready : HealthConnectState
}

/** Records read from Health Connect, ready to POST to the API. */
data class HealthUploads(
    val activities: List<NewActivityDto> = emptyList(),
    val nutrition: List<NewNutritionDto> = emptyList(),
) {
    val isEmpty: Boolean get() = activities.isEmpty() && nutrition.isEmpty()
}

/** Read result plus a human-readable error when the read itself failed. */
data class HealthReadResult(
    val uploads: HealthUploads = HealthUploads(),
    val error: String? = null,
) {
    val summary: String
        get() = when {
            error != null -> error
            else -> "${uploads.activities.size} sessions · ${uploads.nutrition.size} meals"
        }
}

/**
 * Read-only Health Connect pipe (ADR-003): reads exercise sessions, active
 * calories, heart rate, and nutrition records, maps them to ingest DTOs with
 * `client_id = hc:<metadata-id>`, and lets the server dedupe. No watermark —
 * re-reading and re-POSTing a window is free, so sync is stateless.
 */
class HealthConnectReader(private val context: Context) {

    suspend fun status(): HealthConnectState = when (HealthConnectClient.getSdkStatus(context)) {
        HealthConnectClient.SDK_UNAVAILABLE -> HealthConnectState.Unavailable
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> HealthConnectState.UpdateRequired
        else -> if (granted() == PERMISSIONS.toSet()) HealthConnectState.Ready
        else HealthConnectState.NeedsPermissions
    }

    /**
     * Read everything since [since] and map it. Never throws — failures come
     * back as [HealthReadResult.error] so the UI can show what happened.
     */
    suspend fun readSince(since: Instant): HealthReadResult {
        val state = status()
        if (state != HealthConnectState.Ready) {
            return HealthReadResult(error = "state: $state")
        }
        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val range = TimeRangeFilter.between(since, Instant.now())

            val sessions = client
                .readRecords(ReadRecordsRequest(ExerciseSessionRecord::class, range))
                .records
            val calories = client
                .readRecords(ReadRecordsRequest(TotalCaloriesBurnedRecord::class, range))
                .records
            val hrSamples = client
                .readRecords(ReadRecordsRequest(HeartRateRecord::class, range))
                .records
                .flatMap { it.samples }

            val activities = sessions.mapNotNull { session ->
                val minutes = java.time.Duration.between(session.startTime, session.endTime)
                if (minutes.isNegative || minutes.isZero) return@mapNotNull null

                val windowCalories = calories
                    .filter { it.startTime < session.endTime && it.endTime > session.startTime }
                    .sumOf { it.energy.inKilocalories }
                val inWindow = hrSamples.filter { it.time >= session.startTime && it.time <= session.endTime }
                val bpm = inWindow.map { it.beatsPerMinute }

                NewActivityDto(
                    startedAt = session.startTime.toString(),
                    endedAt = session.endTime.toString(),
                    minutes = minutes.toMinutes().toInt(),
                    caloriesKcal = windowCalories.takeIf { it > 0.0 },
                    avgHr = bpm.takeIf { it.isNotEmpty() }?.average()?.toInt(),
                    maxHr = bpm.maxOrNull()?.toInt(),
                    source = session.metadata.dataOrigin.packageName,
                    clientId = "hc:${session.metadata.id}",
                )
            }

            val nutrition = client
                .readRecords(ReadRecordsRequest(NutritionRecord::class, range))
                .records
                .mapNotNull { meal ->
                    val carbs = meal.totalCarbohydrate?.inGrams
                    val kcal = meal.energy?.inKilocalories
                    // Backend requires > 0 on any present value; a zero-carbs
                    // food (black coffee) must send carbs as null, not 0.
                    val carbsClean = carbs?.takeIf { it > 0.0 }
                    val kcalClean = kcal?.takeIf { it > 0.0 }
                    if (carbsClean == null && kcalClean == null) return@mapNotNull null
                    NewNutritionDto(
                        takenAt = meal.startTime.toString(),
                        carbsG = carbsClean,
                        caloriesKcal = kcalClean,
                        mealType = mealType(meal.mealType),
                        source = meal.metadata.dataOrigin.packageName,
                        clientId = "hc:${meal.metadata.id}",
                    )
                }

            HealthReadResult(
                uploads = HealthUploads(
                    activities = activities.distinctBy { it.clientId },
                    nutrition = nutrition.distinctBy { it.clientId },
                ),
            )
        } catch (e: Exception) {
            // Health Connect hiccup — never block the app; surface it instead.
            HealthReadResult(error = "read failed: ${e.javaClass.simpleName}: ${e.message?.take(120)}")
        }
    }

    private suspend fun granted(): Set<String> = try {
        HealthConnectClient.getOrCreate(context).permissionController.getGrantedPermissions()
    } catch (_: Exception) {
        emptySet()
    }

    private fun mealType(type: Int): String? = when (type) {
        MealType.MEAL_TYPE_BREAKFAST -> "breakfast"
        MealType.MEAL_TYPE_LUNCH -> "lunch"
        MealType.MEAL_TYPE_DINNER -> "dinner"
        MealType.MEAL_TYPE_SNACK -> "snack"
        else -> null
    }

    companion object {
        /** Read-only scope per ADR-003 — A1See never writes to Health Connect. */
        val PERMISSIONS = listOf(
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getReadPermission(NutritionRecord::class),
        )

        /** How far back each refresh re-reads, in days. Idempotent server makes overlap free. */
        const val READ_WINDOW_DAYS = 7L
    }
}
