package com.a1c.app.data.api

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class DoseDto(
    val id: Long,
    val kind: String,
    val units: Int,
    @SerialName("created_at") val createdAt: String,
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
data class NewDoseDto(
    val units: Int,
    val kind: String,
)

@Serializable
data class DoseResponseDto(
    val dose: DoseDto,
)

@Serializable
data class SettingsDto(
    @SerialName("fast_name") val fastName: String,
    @SerialName("slow_name") val slowName: String,
    @SerialName("weight_kg") val weightKg: Double?,
    @SerialName("last_a1c") val lastA1c: Double?,
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
