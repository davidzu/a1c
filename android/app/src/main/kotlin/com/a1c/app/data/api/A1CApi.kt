package com.a1c.app.data.api

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PATCH

interface A1CApi {
    @GET("doses")
    suspend fun doses(): DosesIndexDto

    @retrofit2.http.POST("doses")
    suspend fun createDose(@Body dose: NewDoseDto): DoseResponseDto

    @GET("settings")
    suspend fun settings(): SettingsResponseDto

    @PATCH("settings")
    suspend fun updateSettings(@Body settings: SettingsDto): SettingsResponseDto

    @GET("glucose")
    suspend fun glucose(@retrofit2.http.Query("hours") hours: Int = 24): GlucoseResponseDto
}
