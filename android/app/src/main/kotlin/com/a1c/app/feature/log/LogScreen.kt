package com.a1c.app.feature.log

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.a1c.app.data.LogData
import com.a1c.app.ui.theme.Accent
import com.a1c.app.ui.theme.OnSurfaceDim
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver

private val timeFormat = DateTimeFormatter.ofPattern("EEE d MMM · HH:mm").withZone(ZoneId.systemDefault())
private val dayLabel = DateTimeFormatter.ofPattern("d MMM")

@Composable
fun LogScreen(data: LogData, onLogDose: (Int, String, (Boolean, String?) -> Unit) -> Unit) {
    var unitsText by remember { mutableStateOf("") }
    var kind by remember { mutableStateOf<String?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var now by remember { mutableStateOf(Instant.now()) }

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) now = Instant.now()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val units = unitsText.toIntOrNull()
    val canSave = units != null && units > 0 && kind != null

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
    ) {
        Text(
            text = timeFormat.format(now),
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onBackground,
        )

        data.settings?.let { settings ->
            val general = listOfNotNull(
                settings.lastA1c?.let { "A1C %.1f".format(it) },
                settings.weightKg?.let { "%.1f kg".format(it) },
            ).joinToString("  ·  ")
            if (general.isNotEmpty()) {
                Text(
                    text = general,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }

        Spacer(Modifier.height(16.dp))

        // Units field
        OutlinedTextField(
            value = unitsText,
            onValueChange = { value -> if (value.all { it.isDigit() }) unitsText = value.take(3) },
            label = { Text("Units:") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(Modifier.height(12.dp))

        // Fast / Slow single choice
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            val fastLabel = data.settings?.fastName ?: "Fast"
            val slowLabel = data.settings?.slowName ?: "Slow"
            ChoiceChip(selected = kind == "fast", label = fastLabel, modifier = Modifier.weight(1f)) { kind = "fast" }
            ChoiceChip(selected = kind == "slow", label = slowLabel, modifier = Modifier.weight(1f)) { kind = "slow" }
        }

        Spacer(Modifier.height(16.dp))

        Button(
            onClick = {
                val selectedKind = kind
                val unitsValue = units
                if (selectedKind != null && unitsValue != null && unitsValue > 0) {
                    onLogDose(unitsValue, selectedKind) { ok, err ->
                        message = if (ok) {
                            unitsText = ""
                            kind = null
                            "Saved $unitsValue u $selectedKind"
                        } else {
                            err ?: "Could not save"
                        }
                    }
                }
            },
            enabled = canSave,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text("Save dose", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        }

        message?.let {
            Text(
                text = it,
                color = if (it.startsWith("Saved")) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 10.dp),
            )
        }

        Spacer(Modifier.height(28.dp))
        Text(
            text = "Daily totals",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(12.dp))
        DailyTotalsGraph(data.dailyTotals)
        Spacer(Modifier.height(24.dp))

        Text(
            text = "Recent doses",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(8.dp))
        if (data.doses.isEmpty()) {
            Text(
                text = "No doses logged yet.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            data.doses.takeLast(10).reversed().forEach { dose ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = dose.kind,
                        color = if (dose.kind == "fast") Accent else MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.Medium,
                    )
                    Text("${dose.units} u", color = MaterialTheme.colorScheme.onBackground)
                    Text(
                        timeFormat.format(Instant.parse(dose.createdAt)),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 13.sp,
                    )
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun ChoiceChip(selected: Boolean, label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = if (selected) Accent else MaterialTheme.colorScheme.surfaceVariant,
        modifier = modifier.height(48.dp),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                text = label,
                color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun DailyTotalsGraph(totals: List<com.a1c.app.data.api.DailyTotalDto>) {
    val recent = totals.takeLast(14)
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            if (recent.isEmpty()) {
                Text(
                    "Log your first dose to see the graph.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                val max = recent.maxOf { it.totalUnits }.coerceAtLeast(1)
                val textMeasurer = rememberTextMeasurer()
                Canvas(modifier = Modifier.fillMaxWidth().height(140.dp)) {
                    val barSpace = size.width / recent.size
                    val barWidth = barSpace * 0.55f
                    recent.forEachIndexed { index, total ->
                        val barHeight = (total.totalUnits.toFloat() / max) * (size.height - 18.dp.toPx())
                        drawRoundRect(
                            color = Accent,
                            topLeft = Offset(index * barSpace + (barSpace - barWidth) / 2, size.height - barHeight),
                            size = Size(barWidth, barHeight),
                            cornerRadius = CornerRadius(6f, 6f),
                        )
                        drawText(
                            textMeasurer = textMeasurer,
                            text = total.totalUnits.toString(),
                            topLeft = Offset(index * barSpace + (barSpace - barWidth) / 2 - 8f, size.height - barHeight - 34f),
                            style = TextStyle(color = OnSurfaceDim, fontSize = 10.sp),
                        )                    }
                }
                Spacer(Modifier.height(8.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(LocalDate.parse(recent.first().date).format(dayLabel), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp)
                    Text(LocalDate.parse(recent.last().date).format(dayLabel), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp)
                }
            }
        }
    }
}
