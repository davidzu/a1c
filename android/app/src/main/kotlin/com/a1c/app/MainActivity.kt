package com.a1c.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.a1c.app.feature.config.ConfigViewModel
import com.a1c.app.feature.config.GeneralsScreen
import com.a1c.app.feature.config.InsulinsScreen
import com.a1c.app.feature.log.LogScreen
import com.a1c.app.feature.log.LogViewModel
import com.a1c.app.ui.theme.A1CTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val container = (application as A1CApplication).container
        setContent {
            A1CTheme {
                A1CApp(container)
            }
        }
    }
}

private sealed class Destination(val route: String, val label: String) {
    data object Log : Destination("log", "Log")
    data object Insulins : Destination("insulins", "Insulins")
    data object Generals : Destination("generals", "Generals")
}

@Composable
fun A1CApp(container: AppContainer) {
    val navController = rememberNavController()
    val logViewModel: LogViewModel = viewModel(factory = SimpleFactory { LogViewModel(container.repository) })
    val configViewModel: ConfigViewModel = viewModel(factory = SimpleFactory { ConfigViewModel(container.repository) })
    val data by logViewModel.log.collectAsState()

    val destinations = listOf(Destination.Log, Destination.Insulins, Destination.Generals)
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                destinations.forEach { destination ->
                    NavigationBarItem(
                        selected = currentRoute == destination.route,
                        onClick = {
                            navController.navigate(destination.route) {
                                popUpTo(navController.graph.startDestinationId) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = {
                            when (destination) {
                                Destination.Log -> Icon(Icons.Filled.Home, contentDescription = null)
                                Destination.Insulins -> Icon(Icons.Filled.List, contentDescription = null)
                                Destination.Generals -> Icon(Icons.Filled.Settings, contentDescription = null)
                            }
                        },
                        label = { Text(destination.label) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.primary,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            indicatorColor = MaterialTheme.colorScheme.surfaceVariant,
                        ),
                    )
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Destination.Log.route,
            modifier = Modifier.padding(padding),
        ) {
            composable(Destination.Log.route) {
                LogScreen(data = data, onLogDose = logViewModel::logDose)
            }
            composable(Destination.Insulins.route) {
                InsulinsScreen(data = data, onSave = configViewModel::save)
            }
            composable(Destination.Generals.route) {
                GeneralsScreen(data = data, onSave = configViewModel::save)
            }
        }
    }
}

class SimpleFactory(private val creator: () -> androidx.lifecycle.ViewModel) : androidx.lifecycle.ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T = creator() as T
}
