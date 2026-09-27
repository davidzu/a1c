package com.a1c.app.feature.config

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.a1c.app.data.LogData
import com.a1c.app.data.api.SettingsDto

@Composable
fun GeneralsScreen(data: LogData, onSave: (SettingsDto, (Boolean, String?) -> Unit) -> Unit) {
    val settings = data.settings
    var weight by remember(settings) { mutableStateOf(settings?.weightKg?.let { it.toString() } ?: "") }
    var a1c by remember(settings) { mutableStateOf(settings?.lastA1c?.let { it.toString() } ?: "") }
    var message by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
    ) {
        Text("Generals", style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onBackground)
        Text(
            "Your current weight and last A1C reading.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp, bottom = 20.dp),
        )

        OutlinedTextField(
            value = weight,
            onValueChange = { value -> if (value.matches(Regex("^\\d*\\.?\\d*$"))) weight = value },
            label = { Text("Weight (kg)") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = a1c,
            onValueChange = { value -> if (value.matches(Regex("^\\d*\\.?\\d*$"))) a1c = value },
            label = { Text("Last A1C") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = {
                val current = settings ?: SettingsDto(fastName = "Fast", slowName = "Slow", weightKg = null, lastA1c = null)
                onSave(
                    current.copy(
                        weightKg = weight.toDoubleOrNull(),
                        lastA1c = a1c.toDoubleOrNull(),
                    )
                ) { ok, err ->
                    message = if (ok) "Saved" else (err ?: "Could not save")
                }
            },
            enabled = (weight.isBlank() || weight.toDoubleOrNull() != null) &&
                (a1c.isBlank() || a1c.toDoubleOrNull() != null),
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
