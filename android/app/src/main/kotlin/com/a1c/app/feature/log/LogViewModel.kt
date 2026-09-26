package com.a1c.app.feature.log

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.a1c.app.data.A1CRepository
import com.a1c.app.data.DoseLogResult
import com.a1c.app.data.LogData
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class LogViewModel(private val repository: A1CRepository) : ViewModel() {

    val log: StateFlow<LogData> = repository.log

    init {
        viewModelScope.launch { runCatching { repository.refresh() } }
    }

    fun logDose(units: Int, kind: String, onDone: (DoseLogResult) -> Unit) {
        viewModelScope.launch {
            onDone(repository.logDose(units, kind))
        }
    }

    /** Called on resume: re-sync the outbox and reload from the server. */
    fun refresh() {
        viewModelScope.launch { runCatching { repository.refresh() } }
    }
}
