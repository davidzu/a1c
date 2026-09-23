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

    fun logDose(units: Int, kind: String, onDone: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            when (val result = repository.logDose(units, kind)) {
                is DoseLogResult.Success -> onDone(true, null)
                is DoseLogResult.Failure -> onDone(false, result.message)
            }
        }
    }
}
