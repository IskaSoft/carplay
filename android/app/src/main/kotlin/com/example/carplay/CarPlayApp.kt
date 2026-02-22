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

            val statusIcon = when (data.tripStatus) {
                "driving" -> CarIcon.Builder(
                    androidx.core.graphics.drawable.IconCompat.createWithResource(
                        carContext, android.R.drawable.ic_media_play
                    )
                ).build()
                "paused" -> CarIcon.Builder(
                    androidx.core.graphics.drawable.IconCompat.createWithResource(
                        carContext, android.R.drawable.ic_media_pause
                    )
                ).build()
                else -> CarIcon.Builder(
                    androidx.core.graphics.drawable.IconCompat.createWithResource(
                        carContext, android.R.drawable.ic_dialog_info
                    )
                ).build()
            }

            // Build a clean, large-text message template
            val title = buildSpeedTitle(data)
            val body = buildBodyText(data)

            MessageTemplate.Builder(body)
                .setTitle(title)
                .setIcon(statusIcon)
                .setHeaderAction(Action.APP_ICON)
                .build()
        } catch (e: Exception) {
            // Fallback: show a simple error message instead of crashing
            MessageTemplate.Builder("An error occurred. Please reopen the app on your phone.")
                .setTitle("CarPlay")
                .setHeaderAction(Action.APP_ICON)
                .build()
        }
    }

    private fun buildSpeedTitle(data: DrivingData): String {
        return if (data.tripStatus == "driving" || data.tripStatus == "paused") {
            "${data.currentSpeedDisplay} ${data.speedUnit}"
        } else {
            "CarPlay"
        }
    }

    private fun buildBodyText(data: DrivingData): String {
        return if (data.tripStatus == "idle" || data.tripStatus == "stopped") {
            "Open the CarPlay app on your phone to start a trip."
        } else {
            "Avg  ${data.averageSpeedDisplay} ${data.speedUnit}\n" +
            "Dist ${data.distanceDisplay}\n" +
            "Time ${data.durationDisplay}"
        }
    }
}
