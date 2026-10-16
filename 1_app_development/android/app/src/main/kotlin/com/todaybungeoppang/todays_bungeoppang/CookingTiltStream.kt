package com.todaybungeoppang.todays_bungeoppang

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel
import kotlin.math.atan2
import kotlin.math.roundToInt

// Local motion input only. No permission, persistence, identifiers or network.
class CookingTiltStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val sensor = manager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
        ?: manager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private var sink: EventChannel.EventSink? = null
    private var foreground = true
    private var samplingUs = 0

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        sink = events
        val requested = (arguments as? Map<*, *>)?.get("samplingMs") as? Number
        val ms = requested?.toLong()
        if ((requested !is Int && requested !is Long) || ms == null || ms <= 0 || ms > Int.MAX_VALUE / 1000) {
            events.error("invalid-sampling", "기울기 입력 간격 오류", null)
            sink = null
            return
        }
        samplingUs = (ms * 1000).toInt()
        start()
    }
    override fun onCancel(arguments: Any?) { stop(); sink = null }
    fun setForeground(value: Boolean) {
        foreground = value
        if (value) start() else stop()
    }
    private fun start() {
        val target = sink ?: return
        if (!foreground || samplingUs <= 0) return
        stop()
        if (sensor == null || manager?.registerListener(this, sensor, samplingUs) != true) {
            target.success(mapOf("available" to false))
            target.endOfStream()
            sink = null
        }
    }
    private fun stop() { manager?.unregisterListener(this) }
    fun dispose() { stop(); sink = null }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onSensorChanged(event: SensorEvent) {
        if (!foreground || event.values.size < 3) return
        val x = event.values[0].toDouble()
        val y = event.values[1].toDouble()
        if (!x.isFinite() || !y.isFinite()) return
        val angle = (Math.toDegrees(atan2(-x, y)) * 1000).roundToInt()
        sink?.success(mapOf("available" to true, "angleMillidegrees" to angle))
    }
}
