package com.example.carplay

import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.model.*
import androidx.car.app.validation.HostValidator
import java.util.concurrent.atomic.AtomicReference

/**
 * Android Auto integration using the Jetpack Car App Library.
 *
 * This service receives driving data from Flutter via the static [updateDrivingData]
 * method and refreshes the car screen template every time data arrives.
 *
 * Manifest registration (see AndroidManifest.xml):
 *   <service android:name=".CarPlayAppService"
 *            android:exported="true"
 *            android:label="@string/app_name">
 *     <intent-filter>
 *       <action android:name="androidx.car.app.CarAppService"/>
 *       <category android:name="androidx.car.app.category.POI"/>  <!-- or NAVIGATION -->
 *     </intent-filter>
 *   </service>
 */
class CarPlayAppService : CarAppService() {

    override fun createHostValidator(): HostValidator = HostValidator.ALLOW_ALL_HOSTS_VALIDATOR

    override fun onCreateSession(): Session = CarPlayAppSession()

    // ── Static data store shared between Flutter bridge and Car screen ────────

    companion object {
        /** Latest snapshot of driving data, written by the Flutter platform channel. */
        internal val latestData = AtomicReference(DrivingData())

        /** Screen reference — set when the car session starts. */
        internal var activeScreen: CarPlayAppDashboardScreen? = null

        fun updateDrivingData(
            currentSpeedDisplay: String,
            averageSpeedDisplay: String,
            speedUnit: String,
            distanceDisplay: String,
            durationDisplay: String,
            tripStatus: String,
            currentSpeedKmh: Double,
            averageSpeedKmh: Double,
        ) {
            latestData.set(
                DrivingData(
                    currentSpeedDisplay = currentSpeedDisplay,
                    averageSpeedDisplay = averageSpeedDisplay,
                    speedUnit           = speedUnit,
                    distanceDisplay     = distanceDisplay,
                    durationDisplay     = durationDisplay,
                    tripStatus          = tripStatus,
                    currentSpeedKmh     = currentSpeedKmh,
                    averageSpeedKmh     = averageSpeedKmh,
                )
            )
            // Invalidate car screen so Android Auto requests a fresh template
            activeScreen?.invalidate()
        }
    }
}

// ─── Data carrier ─────────────────────────────────────────────────────────────

data class DrivingData(
    val currentSpeedDisplay: String = "0",
    val averageSpeedDisplay: String = "0",
    val speedUnit: String = "km/h",
    val distanceDisplay: String = "0 km",
    val durationDisplay: String = "00:00",
    val tripStatus: String = "idle",
    val currentSpeedKmh: Double = 0.0,
    val averageSpeedKmh: Double = 0.0,
)

// ─── Session ──────────────────────────────────────────────────────────────────

class CarPlayAppSession : Session() {
    override fun onCreateScreen(intent: android.content.Intent): Screen {
        val screen = CarPlayAppDashboardScreen(carContext)
        CarPlayAppService.activeScreen = screen
        return screen
    }
}

// ─── Car Screen ───────────────────────────────────────────────────────────────

/**
 * Renders a MessageTemplate (approved for all car categories) showing speed data.
 *
 * NOTE: Android Auto enforces strict template restrictions.
 * We use MessageTemplate as it requires no navigation permission and
 * is allowed in the POI / general category apps.
 *
 * For apps with NAVIGATION category, use NavigationTemplate for richer UI.
 */
class CarPlayAppDashboardScreen(carContext: androidx.car.app.CarContext) :
    Screen(carContext) {

    override fun onGetTemplate(): Template {
        return try {
            val data = CarPlayAppService.latestData.get()

            val paneBuilder = Pane.Builder()

            if (data.tripStatus == "idle" || data.tripStatus == "stopped") {
                paneBuilder.addRow(
                    Row.Builder()
                        .setTitle("CarPlay")
                        .addText("Open the app on your phone to start.")
                        .build()
                )
            } else {
                paneBuilder.addRow(
                    Row.Builder()
                        .setTitle("Speed")
                        .addText("${data.currentSpeedDisplay} ${data.speedUnit}")
                        .build()
                )
                paneBuilder.addRow(
                    Row.Builder()
                        .setTitle("Average & Distance")
                        .addText("Avg: ${data.averageSpeedDisplay} ${data.speedUnit}  |  Dist: ${data.distanceDisplay}")
                        .build()
                )
                paneBuilder.addRow(
                    Row.Builder()
                        .setTitle("Time")
                        .addText(data.durationDisplay)
                        .build()
                )
            }

            PaneTemplate.Builder(paneBuilder.build())
                .setHeaderAction(Action.APP_ICON)
                .setTitle(if (data.tripStatus == "driving") "Driving Active" else "CarPlay")
                .build()

        } catch (e: Exception) {
            val errorMsg = e.message ?: "Unknown error"
            val errorPane = Pane.Builder()
                .addRow(Row.Builder().setTitle("Error").addText(errorMsg).build())
                .build()
            
            PaneTemplate.Builder(errorPane)
                .setHeaderAction(Action.APP_ICON)
                .setTitle("CarPlay Error")
                .build()
        }
    }
}
