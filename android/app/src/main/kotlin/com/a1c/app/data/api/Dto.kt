package com.a1c.app.data.api

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class DoseDto(
    val id: Long,
    val kind: String,
    val units: Int,
    @SerialName("created_at") val createdAt: String,
    @SerialName("taken_at") val takenAt: String? = null,
    @SerialName("client_id") val clientId: String? = null,
)

@Serializable
data class DailyTotalDto(
    val date: String,
    @SerialName("fast_units") val fastUnits: Int = 0,
    @SerialName("slow_units") val slowUnits: Int = 0,
    @SerialName("total_units") val totalUnits: Int,
)

@Serializable
data class DosesIndexDto(
    val doses: List<DoseDto>,
    @SerialName("daily_totals") val dailyTotals: List<DailyTotalDto>,
)

@Serializable
data class GlucoseReadingDto(
    val time: String,
    val sgv: Int,
    @SerialName("mmol_l") val mmolL: Double? = null,
    val direction: String? = null,
)

@Serializable
data class GlucoseResponseDto(
    val glucose: List<GlucoseReadingDto>,
)

@Serializable
data class NewDoseDto(
    val units: Int,
    val kind: String,
    @SerialName("taken_at") val takenAt: String? = null,
    @SerialName("client_id") val clientId: String? = null,
)

@Serializable
data class DoseResponseDto(
    val dose: DoseDto,
)

@Serializable
data class SettingsDto(
    @SerialName("fast_name") val fastName: String,
    @SerialName("slow_name") val slowName: String,
    @SerialName("weight_kg") val weightKg: Double? = null,
    @SerialName("last_a1c") val lastA1c: Double? = null,
    val timezone: String? = null,
)

@Serializable
data class SettingsResponseDto(
    val settings: SettingsDto,
)

@Serializable
data class ApiErrorDto(
    val code: String,
    val message: String,
    val field: String? = null,
)

@Serializable
data class ApiErrorResponseDto(
    val error: ApiErrorDto,
)

// --- v2.x: activity + nutrition + day context (ADR-003) ---

@Serializable
data class NewActivityDto(
    @SerialName("started_at") val startedAt: String,
    @SerialName("ended_at") val endedAt: String,
    val minutes: Int? = null,
    @SerialName("calories_kcal") val caloriesKcal: Double? = null,
    @SerialName("avg_hr") val avgHr: Int? = null,
    @SerialName("max_hr") val maxHr: Int? = null,
    val source: String? = null,
    @SerialName("client_id") val clientId: String,
)

@Serializable
data class NewNutritionDto(
    @SerialName("taken_at") val takenAt: String,
    @SerialName("carbs_g") val carbsG: Double? = null,
    @SerialName("calories_kcal") val caloriesKcal: Double? = null,
    @SerialName("meal_type") val mealType: String? = null,
    val source: String? = null,
    @SerialName("client_id") val clientId: String,
)

@Serializable
data class IngestResultDto(
    val ingested: Int,
    val received: Int,
)

@Serializable
data class ActivityDto(
    val id: Long,
    @SerialName("started_at") val startedAt: String,
    @SerialName("ended_at") val endedAt: String,
    val minutes: Int,
    @SerialName("calories_kcal") val caloriesKcal: Double? = null,
    @SerialName("avg_hr") val avgHr: Int? = null,
    @SerialName("max_hr") val maxHr: Int? = null,
    val source: String? = null,
)

@Serializable
data class NutritionDto(
    val id: Long,
    @SerialName("taken_at") val takenAt: String,
    @SerialName("carbs_g") val carbsG: Double? = null,
    @SerialName("calories_kcal") val caloriesKcal: Double? = null,
    @SerialName("meal_type") val mealType: String? = null,
    val source: String? = null,
)

@Serializable
data class DayDto(
    val date: String,
    @SerialName("fast_units") val fastUnits: Int = 0,
    @SerialName("slow_units") val slowUnits: Int = 0,
    @SerialName("total_units") val totalUnits: Int = 0,
    @SerialName("carbs_g") val carbsG: Int = 0,
    @SerialName("calories_kcal") val caloriesKcal: Int = 0,
    @SerialName("exercise_min") val exerciseMin: Int = 0,
)

@Serializable
data class DaysResponseDto(
    val days: List<DayDto>,
)

@Serializable
data class ActivitiesResponseDto(
    val activities: List<ActivityDto>,
)

@Serializable
data class NutritionResponseDto(
    val nutrition: List<NutritionDto>,
)
