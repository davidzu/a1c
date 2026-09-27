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
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import com.a1c.app.data.DoseLogResult
import com.a1c.app.data.LogData
import com.a1c.app.data.api.GlucoseReadingDto
import com.a1c.app.ui.theme.Accent
import com.a1c.app.ui.theme.AccentDim
import com.a1c.app.ui.theme.OnSurfaceDim
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver

private val timeFormat = DateTimeFormatter.ofPattern("EEE d MMM · HH:mm").withZone(ZoneId.systemDefault())
private val dayLabel = DateTimeFormatter.ofPattern("d MMM")

@Composable
fun LogScreen(
    data: LogData,
    onLogDose: (Int, String, (DoseLogResult) -> Unit) -> Unit,
    onRefresh: () -> Unit,
) {
    var unitsText by remember { mutableStateOf("") }
    var kind by remember { mutableStateOf<String?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var messageIsError by remember { mutableStateOf(false) }
    var now by remember { mutableStateOf(Instant.now()) }
    val haptic = LocalHapticFeedback.current

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                now = Instant.now()
                onRefresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val units = unitsText.toIntOrNull()
    val canSave = units != null && units > 0 && kind != null

    // Success feedback clears itself; errors stay until the next action.
    LaunchedEffect(message) {
        if (message != null && !messageIsError) {
            delay(2500)
            message = null
        }
    }

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

        CurrentGlucoseLine(glucose = data.glucose)

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
                    // Instant feedback: clear the form right away (the dose is
                    // persisted locally by the repository before any network
                    // round-trip), then confirm via the callback.
                    unitsText = ""
                    kind = null
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onLogDose(unitsValue, selectedKind) { result ->
                        when (result) {
                            is DoseLogResult.Success -> {
                                messageIsError = false
                                message = "✓ Saved $unitsValue u $selectedKind"
                            }
                            is DoseLogResult.Offline -> {
                                messageIsError = false
                                message = "✓ Saved offline — will sync when online"
                            }
                            is DoseLogResult.Failure -> {
                                messageIsError = true
                                message = result.message
                            }
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
                color = if (messageIsError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (messageIsError) FontWeight.Normal else FontWeight.SemiBold,
                modifier = Modifier.padding(top = 10.dp),
            )
        }

        if (data.pendingCount > 0) {
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.padding(top = 10.dp),
            ) {
                Text(
                    text = "⏳ ${data.pendingCount} pending sync",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
        }

        Spacer(Modifier.height(28.dp))
        Text(
            text = "Daily totals",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(12.dp))
        if (data.loadError != null && data.dailyTotals.isEmpty() && data.doses.isEmpty() && data.pendingCount == 0) {
            ErrorState(
                message = data.loadError,
                onRetry = onRefresh,
            )
        } else {
            DailyTotalsGraph(
                totals = data.dailyTotals,
                fastName = data.settings?.fastName ?: "Fast",
                slowName = data.settings?.slowName ?: "Slow",
            )
        }
        Spacer(Modifier.height(24.dp))

        GlucoseCard(glucose = data.glucose)

        Spacer(Modifier.height(24.dp))

        Text(
            text = "Recent doses",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(8.dp))
        when {
            data.loadError != null && data.doses.isEmpty() && data.pendingCount == 0 ->
                ErrorState(
                    message = data.loadError,
                    onRetry = onRefresh,
                )
            data.doses.isEmpty() -> EmptyState(text = "No doses logged yet.")
            else ->
            data.doses.takeLast(10).reversed().forEach { dose ->
                val kindLabel = when (dose.kind) {
                    "fast" -> data.settings?.fastName ?: "Fast"
                    else -> data.settings?.slowName ?: "Slow"
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = kindLabel,
                        color = if (dose.kind == "fast") Accent else MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.Medium,
                    )
                    Text("${dose.units} u", color = MaterialTheme.colorScheme.onBackground)
                    Text(
                        text = timeFormat.format(Instant.parse(dose.createdAt)) + if (dose.id < 0) " · pending" else "",
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
private fun EmptyState(text: String) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "·",
                style = MaterialTheme.typography.headlineMedium,
                color = AccentDim,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = text,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 32.dp, horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "⚠",
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.error,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = message,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(16.dp))
            OutlinedButton(
                onClick = onRetry,
                shape = RoundedCornerShape(12.dp),
            ) {
                Text("Retry")
            }
        }
    }
}

private val clockLabel = DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.systemDefault())

/** Nightscout direction names → arrows. */
private fun directionArrow(direction: String?): String = when (direction) {
    "DoubleUp" -> "↑↑"
    "SingleUp" -> "↑"
    "FortyFiveUp" -> "↗"
    "Flat" -> "→"
    "FortyFiveDown" -> "↘"
    "SingleDown" -> "↓"
    "DoubleDown" -> "↓↓"
    else -> ""
}

/** Nightscout direction names → arrows. */

private fun GlucoseReadingDto.ageMinutes(now: Instant): Long =
    runCatching { (now.toEpochMilli() - Instant.parse(time).toEpochMilli()) / 60_000 }
        .getOrDefault(-1)

@Composable
private fun CurrentGlucoseLine(glucose: List<GlucoseReadingDto>, now: Instant = Instant.now()) {
    val latest = glucose.lastOrNull() ?: return
    val age = latest.ageMinutes(now)
    val stale = age < 0 || age > 30

    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 10.dp)) {
        Text(
            text = "%.1f mmol/L".format(latest.mmolL ?: latest.sgv / 18.0),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            color = if (stale) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onBackground,
        )
        val arrow = directionArrow(latest.direction)
        if (arrow.isNotEmpty()) {
            Text(
                text = " $arrow",
                style = MaterialTheme.typography.titleLarge,
                color = Accent,
            )
        }
        Text(
            text = when {
                age < 0 -> ""
                age < 1 -> " · now"
                age < 60 -> " · ${age} min ago"
                else -> " · ${age / 60} h ago"
            },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun GlucoseCard(glucose: List<GlucoseReadingDto>) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Glucose · last 24 h",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Spacer(Modifier.height(12.dp))
            if (glucose.size < 2) {
                Text(
                    "Waiting for glucose data — connect xDrip to the A1See API.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                GlucoseChart(glucose)
                Spacer(Modifier.height(10.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(clockLabel.format(Instant.parse(glucose.first().time)), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp)
                    Text("target 3.9–10", color = AccentDim, fontSize = 11.sp)
                    Text(clockLabel.format(Instant.parse(glucose.last().time)), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp)
                }
            }
        }
    }
}

@Composable
private fun GlucoseChart(readings: List<GlucoseReadingDto>) {
    val mmol = readings.map { it.mmolL ?: it.sgv / 18.0 }
    val times = readings.map { Instant.parse(it.time).toEpochMilli() }
    val t0 = times.first()
    val t1 = times.last()
    val span = (t1 - t0).coerceAtLeast(1)
    val lo = (mmol.min() - 0.5).coerceAtLeast(2.0)
    val hi = (mmol.max() + 0.5).coerceAtLeast(lo + 2.0)
    val bandTop = 10.0.coerceAtMost(hi)
    val bandBottom = 3.9.coerceAtLeast(lo)
    val lineColor = Accent

    Canvas(modifier = Modifier.fillMaxWidth().height(140.dp)) {
        val pad = 2.dp.toPx()
        fun y(v: Double): Float {
            val frac = ((v - lo) / (hi - lo)).coerceIn(0.0, 1.0)
            return (size.height - pad) - (frac * (size.height - 2 * pad)).toFloat()
        }

        // Target band 3.9–10 mmol/L
        drawRoundRect(
            color = AccentDim.copy(alpha = 0.15f),
            topLeft = Offset(0f, y(bandTop)),
            size = Size(size.width, y(bandBottom) - y(bandTop)),
            cornerRadius = CornerRadius(6f, 6f),
        )

        // Curve
        val path = Path().apply {
            times.forEachIndexed { i, t ->
                val x = ((t - t0).toFloat() / span) * size.width
                if (i == 0) moveTo(x, y(mmol[i])) else lineTo(x, y(mmol[i]))
            }
        }
        drawPath(path, color = lineColor, style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round))

        // Latest point
        val lastX = ((times.last() - t0).toFloat() / span) * size.width
        drawCircle(color = lineColor, radius = 4.dp.toPx(), center = Offset(lastX, y(mmol.last())))
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
private fun DailyTotalsGraph(totals: List<com.a1c.app.data.api.DailyTotalDto>, fastName: String, slowName: String) {
    val recent = totals.takeLast(14)
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            if (recent.isEmpty()) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        "Log your first dose to see the graph.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                val max = maxOf(recent.maxOf { it.fastUnits }, recent.maxOf { it.slowUnits }).coerceAtLeast(1)
                val textMeasurer = rememberTextMeasurer()
                val slowBarColor = AccentDim.copy(alpha = 0.40f)
                Canvas(modifier = Modifier.fillMaxWidth().height(150.dp)) {
                    val slot = size.width / recent.size
                    val slowBarWidth = slot * 0.72f
                    val fastBarWidth = slot * 0.34f
                    val chartHeight = size.height - 24.dp.toPx()
                    recent.forEachIndexed { index, day ->
                        val slowHeight = (day.slowUnits.toFloat() / max) * chartHeight
                        val slowX = index * slot + (slot - slowBarWidth) / 2
                        if (day.slowUnits > 0) {
                            drawRoundRect(
                                color = slowBarColor,
                                topLeft = Offset(slowX, size.height - slowHeight),
                                size = Size(slowBarWidth, slowHeight),
                                cornerRadius = CornerRadius(7f, 7f),
                            )
                        }
                        val fastHeight = (day.fastUnits.toFloat() / max) * chartHeight
                        val fastX = index * slot + (slot - fastBarWidth) / 2
                        if (day.fastUnits > 0) {
                            drawRoundRect(
                                color = Accent,
                                topLeft = Offset(fastX, size.height - fastHeight),
                                size = Size(fastBarWidth, fastHeight),
                                cornerRadius = CornerRadius(7f, 7f),
                            )
                            val label = textMeasurer.measure(
                                day.fastUnits.toString(),
                                style = TextStyle(color = Accent, fontSize = 11.sp, fontWeight = FontWeight.SemiBold),
                            )
                            drawText(
                                textLayoutResult = label,
                                topLeft = Offset(fastX + fastBarWidth / 2 - label.size.width / 2f, size.height - fastHeight - label.size.height - 4f),
                            )
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(LocalDate.parse(recent.first().date).format(dayLabel), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp)
                    Text(LocalDate.parse(recent.last().date).format(dayLabel), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp)
                }
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    LegendDot(Accent, "Fast · $fastName")
                    LegendDot(slowBarColor, "Slow · $slowName")
                }
            }
        }
    }
}

@Composable
private fun LegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .background(color, RoundedCornerShape(3.dp)),
        )
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.sp)
    }
}
