package com.a1c.app

import android.app.Application

class A1CApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(BuildConfig.BASE_URL, applicationContext)
    }
}
