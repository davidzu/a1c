package com.a1c.app.data

import com.a1c.app.data.api.A1CApi
import com.a1c.app.data.api.DailyTotalDto
import com.a1c.app.data.api.DoseDto
import com.a1c.app.data.api.NewDoseDto
import com.a1c.app.data.api.SettingsDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

sealed interface DoseLogResult {
    data object Success : DoseLogResult
    data class Failure(val message: String) : DoseLogResult
}

class A1CRepository(private val api: A1CApi) {

    private val _log = MutableStateFlow(LogData.empty())
    val log: StateFlow<LogData> = _log.asStateFlow()

    suspend fun refresh() {
        val doses = api.doses()
        val settings = try {
            api.settings().settings
        } catch (_: Exception) {
            null
        }
        _log.update { LogData(doses = doses.doses, dailyTotals = doses.dailyTotals, settings = settings ?: it.settings) }
    }

    suspend fun logDose(units: Int, kind: String): DoseLogResult = try {
        api.createDose(NewDoseDto(units = units, kind = kind))
        refresh()
        DoseLogResult.Success
    } catch (e: Exception) {
        DoseLogResult.Failure(e.message ?: "Network error")
    }

    suspend fun saveSettings(settings: SettingsDto): DoseLogResult = try {
        val updated = api.updateSettings(settings).settings
        _log.update { it.copy(settings = updated) }
        DoseLogResult.Success
    } catch (e: Exception) {
        DoseLogResult.Failure(e.message ?: "Network error")
    }
}

data class LogData(
    val doses: List<DoseDto>,
    val dailyTotals: List<DailyTotalDto>,
    val settings: SettingsDto?,
) {
    companion object {
        fun empty() = LogData(emptyList(), emptyList(), null)
    }
}
