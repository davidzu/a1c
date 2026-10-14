package com.a1c.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Dark-only palette: black / grey surfaces, purple-pink accent.
val Background = Color(0xFF0A0A0C)
val Surface = Color(0xFF141418)
val SurfaceHigh = Color(0xFF1E1E24)
val OnSurface = Color(0xFFE8E6EC)
val OnSurfaceDim = Color(0xFF9A97A3)
val Accent = Color(0xFFC465D8)
val AccentDim = Color(0xFF8A4A9E)
val OnAccent = Color(0xFF1A0B20)

// Metric identity colors — one hue per metric, used everywhere data
// appears (log screen, glucose card, day bars, doctor report). See
// docs/design-system.md. Accent is interactive chrome only, never data.
// Insulin hues follow the actual pens: NovoRapid is orange, Ryzodeg's
// cap is blue. InsulinOnBoard is the insulin currently acting — red,
// reserved for this one card, never error.
val Glucose = Color(0xFF22D3EE)
val InsulinFast = Color(0xFFFB923C)
val InsulinSlow = Color(0xFF60A5FA)
val Food = Color(0xFFFACC15)
val Exercise = Color(0xFF4ADE80)
val InsulinOnBoard = Color(0xFFF87171)

private val A1CColors = darkColorScheme(
    primary = Accent,
    onPrimary = OnAccent,
    primaryContainer = AccentDim,
    onPrimaryContainer = OnSurface,
    secondary = AccentDim,
    onSecondary = OnSurface,
    background = Background,
    onBackground = OnSurface,
    surface = Surface,
    onSurface = OnSurface,
    surfaceVariant = SurfaceHigh,
    onSurfaceVariant = OnSurfaceDim,
    outline = Color(0xFF3A3744),
    error = Color(0xFFE5646E),
    onError = Color(0xFF2A0A0E),
)

@Composable
fun A1CTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = A1CColors, content = content)
}
