package com.example.agri_chain

import android.content.res.AssetManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Tensor
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "agri_chain/tflite"
    private var interpreter: Interpreter? = null
    private val executor = Executors.newSingleThreadExecutor()
    
    // Debug logging
    private fun log(message: String) {
        println(" [TFLite] $message")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            log("Method called: ${call.method}")
            when (call.method) {
                "loadModel" -> loadModel(call, result)
                "run" -> runInference(call, result)
                "close" -> closeModel(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun loadModel(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                val modelPath = call.argument<String>("modelPath")
                    ?: throw IllegalArgumentException("Missing required argument: modelPath")
                val threads = call.argument<Int>("threads") ?: 2
                val useGPU = call.argument<Boolean>("useGPU") ?: false

                log("Loading model from: $modelPath")
                log("Threads: $threads, Use GPU: $useGPU")

                val options = Interpreter.Options().apply {
                    setNumThreads(threads)
                    // For debugging, don't use GPU delegate initially
                    // if (useGPU) {
                    //     addDelegate(GpuDelegate())
                    // }
                }

                val modelFile = java.io.File(modelPath)
                if (!modelFile.exists()) {
                    throw IllegalArgumentException("Model file not found: $modelPath")
                }
                
                val modelBuffer = loadModelFile(modelFile)
                log("Model file size: ${modelFile.length()} bytes")
                
                interpreter = Interpreter(modelBuffer, options)
                
                // Get input tensor info
                val inputTensor = interpreter?.getInputTensor(0)
                val inputShape = inputTensor?.shape()
                val inputType = inputTensor?.dataType()
                val inputQuantScale = inputTensor?.quantizationParams()?.scale
                val inputQuantZeroPoint = inputTensor?.quantizationParams()?.zeroPoint
                
                // Get output tensor info
                val outputTensor = interpreter?.getOutputTensor(0)
                val outputShape = outputTensor?.shape()
                val outputType = outputTensor?.dataType()
                
                log("Input shape: ${inputShape?.contentToString()}")
                log("Input type: $inputType")
                log("Input quant: scale=$inputQuantScale zeroPoint=$inputQuantZeroPoint")
                log("Output shape: ${outputShape?.contentToString()}")
                log("Output type: $outputType")

                val response = hashMapOf<String, Any>(
                    "inputShape" to (inputShape?.toList() ?: listOf()),
                    "inputType" to (inputType?.name ?: "UNKNOWN"),
                    "inputQuantScale" to (inputQuantScale ?: 0.0f),
                    "inputQuantZeroPoint" to (inputQuantZeroPoint ?: 0L),
                    "outputShape" to (outputShape?.toList() ?: listOf()),
                    "outputType" to (outputType?.name ?: "UNKNOWN")
                )
                
                log("Model loaded successfully")
                result.success(response)
                
            } catch (e: Exception) {
                log("Load error: ${e.message}")
                result.error("LOAD_ERROR", e.message, e.stackTraceToString())
            }
        }
    }

    private fun runInference(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                val inputBytes = call.argument<ByteArray>("input")
                    ?: throw IllegalArgumentException("Missing required argument: input")
                val interpreter = interpreter ?: throw IllegalStateException("Model not loaded")
                
                log("Inference started")
                log("Input bytes size: ${inputBytes.size}")
                
                // CRITICAL FIX: Create ByteBuffer properly
                // Flutter sends Float32 values as bytes, we need to wrap them
                val inputBuffer = ByteBuffer.wrap(inputBytes)
                    .order(ByteOrder.nativeOrder())
                
                // Verify input tensor expects Float32
                val inputTensor = interpreter.getInputTensor(0)
                val expectedSize = inputTensor.numBytes()
                
                log("Input tensor expects: $expectedSize bytes")
                log("Input buffer has: ${inputBuffer.remaining()} bytes")
                
                if (inputBuffer.remaining() != expectedSize) {
                    throw IllegalArgumentException(
                        "Input size mismatch. Expected $expectedSize bytes, got ${inputBuffer.remaining()}"
                    )
                }
                
                // Prepare output
                val outputTensor = interpreter.getOutputTensor(0)
                val outputShape = outputTensor.shape()
                val outputSize = outputTensor.numElements()
                
                log("Output shape: ${outputShape.contentToString()}")
                log("Output size: $outputSize elements")
                
                val outputBuffer = Array(1) { FloatArray(outputSize) }

                // Run inference - pass ByteBuffer directly
                interpreter.run(inputBuffer, outputBuffer)
                
                log("Inference completed")

                val flatOutput = outputBuffer[0]
                log("First 3 outputs: ${flatOutput.take(3).joinToString()}")
                log("Output sum: ${flatOutput.sum()}")
                
                // Convert to list
                result.success(flatOutput.toList())
                
            } catch (e: Exception) {
                log("Inference error: ${e.message}")
                result.error("INFERENCE_ERROR", e.message, e.stackTraceToString())
            }
        }
    }

    private fun closeModel(result: MethodChannel.Result) {
        executor.execute {
            try {
                log("Closing model")
                interpreter?.close()
                interpreter = null
                result.success(null)
            } catch (e: Exception) {
                result.error("CLOSE_ERROR", e.message, null)
            }
        }
    }

    private fun loadModelFile(file: java.io.File): ByteBuffer {
        FileInputStream(file).use { fis ->
            val channel = fis.channel
            val buffer = channel.map(FileChannel.MapMode.READ_ONLY, 0, file.length())
            buffer.order(ByteOrder.nativeOrder())
            return buffer
        }
    }

    override fun onDestroy() {
        log("Activity destroying")
        executor.shutdown()
        interpreter?.close()
        super.onDestroy()
    }
}