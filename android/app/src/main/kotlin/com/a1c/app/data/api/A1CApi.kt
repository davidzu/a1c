package com.a1c.app.data.api

import com.a1c.app.data.api.ActivitiesResponseDto
import com.a1c.app.data.api.DaysResponseDto
import com.a1c.app.data.api.IngestResultDto
import com.a1c.app.data.api.NewActivityDto
import com.a1c.app.data.api.NewNutritionDto
import com.a1c.app.data.api.NutritionResponseDto
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Query

interface A1CApi {
    @GET("doses")
    suspend fun doses(): DosesIndexDto

    @POST("doses")
    suspend fun createDose(@Body dose: NewDoseDto): DoseResponseDto

    @GET("settings")
    suspend fun settings(): SettingsResponseDto

    @PATCH("settings")
    suspend fun updateSettings(@Body settings: SettingsDto): SettingsResponseDto

    @GET("glucose")
    suspend fun glucose(@Query("hours") hours: Int = 24): GlucoseResponseDto

    @POST("activities")
    suspend fun createActivities(@Body body: List<NewActivityDto>): IngestResultDto

    @GET("activities")
    suspend fun activities(@Query("hours") hours: Int = 24): ActivitiesResponseDto

    @POST("nutrition")
    suspend fun createNutrition(@Body body: List<NewNutritionDto>): IngestResultDto

    @GET("nutrition")
    suspend fun nutrition(@Query("hours") hours: Int = 24): NutritionResponseDto

    @GET("days")
    suspend fun days(@Query("days") days: Int = 14): DaysResponseDto
}
