package com.a1c.app.feature.config

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.a1c.app.data.LogData
import com.a1c.app.data.api.SettingsDto

@Composable
fun InsulinsScreen(data: LogData, onSave: (SettingsDto, (Boolean, String?) -> Unit) -> Unit) {
    val settings = data.settings
    var fast by remember(settings) { mutableStateOf(settings?.fastName ?: "") }
    var slow by remember(settings) { mutableStateOf(settings?.slowName ?: "") }
    var message by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
    ) {
        Text("Insulins", style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onBackground)
        Text(
            "Which insulin you use for each kind.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp, bottom = 20.dp),
        )

        OutlinedTextField(
            value = fast,
            onValueChange = { fast = it },
            label = { Text("Fast") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = slow,
            onValueChange = { slow = it },
            label = { Text("Slow") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = {
                val current = settings ?: SettingsDto(fastName = "", slowName = "", weightKg = null, lastA1c = null)
                onSave(current.copy(fastName = fast.trim(), slowName = slow.trim())) { ok, err ->
                    message = if (ok) "Saved" else (err ?: "Could not save")
                }
            },
            enabled = fast.isNotBlank() && slow.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text("Save", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        }
        message?.let {
            Text(
                it,
                color = if (it == "Saved") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(top = 10.dp),
            )
        }
    }
}
