package com.a1c.app

import android.content.Context
import com.a1c.app.data.A1CRepository
import com.a1c.app.data.HealthConnectReader
import com.a1c.app.data.Outbox
import com.a1c.app.data.api.A1CApi
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory

class AppContainer(baseUrl: String, appContext: Context) {
    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    private val okHttp = OkHttpClient.Builder().build()

    private val api: A1CApi = Retrofit.Builder()
        .baseUrl(baseUrl)
        .client(okHttp)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()
        .create(A1CApi::class.java)

    val repository = A1CRepository(api, Outbox(appContext), HealthConnectReader(appContext))
}

