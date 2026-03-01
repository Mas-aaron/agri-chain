package com.example.mindspore_lite_flutter;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.mindspore.Model;
import com.mindspore.MSTensor;
import com.mindspore.config.CpuBindMode;
import com.mindspore.config.DeviceType;
import com.mindspore.config.MSContext;
import com.mindspore.config.ModelType;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * MindsporeLiteFlutterPlugin
 *
 * CRITICAL FIX: MSContext lifecycle.
 * MindSpore Lite's model.build() TAKES OWNERSHIP of the MSContext.
 * After build(), the model manages the context internally.
 * Therefore:
 *   - We must create a FRESH MSContext for each model.build() call.
 *   - We must NOT call context.free() after build() — that would double-free.
 *   - When model.free() is called, it frees the associated context too.
 * 
 * Previous crashes were caused by:
 *   v1: Calling context.free() after build() → double-free → Scudo error
 *   v2: Reusing a persistent context across builds → stale/freed native ptr → crash
 */
public class MindsporeLiteFlutterPlugin implements FlutterPlugin, MethodCallHandler {

    private static final String TAG     = "MindSporeLite";
    private static final String CHANNEL = "com.agrichain.mindspore";

    private volatile boolean nativeLibsLoaded = false;

    private MethodChannel   channel;
    private Model           msModel;
    private Context         appContext;

    // Single-thread executor serializes all native calls — no race conditions
    private final ExecutorService executor    = Executors.newSingleThreadExecutor();
    private final Handler         mainHandler = new Handler(Looper.getMainLooper());

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        appContext = binding.getApplicationContext();
        channel    = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        Log.d(TAG, "Plugin attached");
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) channel.setMethodCallHandler(null);
        executor.submit(this::releaseResources);
        executor.shutdown();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        final Result safe = new MainThreadResult(result, mainHandler);

        switch (call.method) {
            case "initModel":
            case "initialize":
                executor.submit(() -> handleInitModel(call, safe));
                break;
            case "predictImage":
                executor.submit(() -> handlePredictImage(call, safe));
                break;
            case "disposeModel":
            case "close":
                executor.submit(() -> { releaseResources(); safe.success(true); });
                break;
            default:
                safe.notImplemented();
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // initModel
    // ─────────────────────────────────────────────────────────────────────────

    private void handleInitModel(MethodCall call, Result result) {
        try {
            if (!nativeLibsLoaded) {
                try { System.loadLibrary("mindspore-lite"); } catch (UnsatisfiedLinkError e) { Log.w(TAG, "mindspore-lite: " + e.getMessage()); }
                try { System.loadLibrary("mindspore-lite-jni"); } catch (UnsatisfiedLinkError e) { Log.w(TAG, "mindspore-lite-jni: " + e.getMessage()); }
                nativeLibsLoaded = true;
            }

            String assetPath = call.argument("modelPath");
            if (assetPath == null || assetPath.isEmpty()) {
                result.success(false);
                return;
            }

            Log.d(TAG, "[initModel] " + assetPath);

            // 1) Copy asset to internal storage
            File modelFile = copyAssetToFile(assetPath);
            if (modelFile == null) {
                result.success(false);
                return;
            }

            // 2) Free old model FIRST (this also frees the old context it owns)
            if (msModel != null) {
                Log.d(TAG, "[initModel] Freeing previous model...");
                try { msModel.free(); } catch (Exception e) { Log.w(TAG, "free old: " + e); }
                msModel = null;
            }

            // 3) Create a FRESH MSContext for each build
            //    model.build() takes ownership — we must NOT free this context.
            MSContext context = new MSContext();
            context.init(2, CpuBindMode.MID_CPU, false);
            context.addDeviceInfo(DeviceType.DT_CPU, false, 0);

            // 4) Build model — context is consumed here
            msModel = new Model();
            String absPath = modelFile.getAbsolutePath();
            Log.d(TAG, "[initModel] Building from: " + absPath + " (" + modelFile.length() + " bytes)");
            boolean built = msModel.build(absPath, ModelType.MT_MINDIR, context);
            // DO NOT call context.free() — the model owns it now!

            if (built) {
                Log.d(TAG, "[initModel] SUCCESS ✅");
            } else {
                Log.e(TAG, "[initModel] FAILED ❌");
                try { msModel.free(); } catch (Exception ignored) {}
                msModel = null;
            }

            result.success(built);

        } catch (Exception e) {
            Log.e(TAG, "[initModel] Exception: " + e.getMessage(), e);
            result.success(false);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // predictImage
    // ─────────────────────────────────────────────────────────────────────────

    private void handlePredictImage(MethodCall call, Result result) {
        if (msModel == null) {
            result.error("NOT_INITIALIZED", "Call initModel() first", null);
            return;
        }
        try {
            String imagePath = call.argument("imagePath");
            String modelType = call.argument("modelType");
            if (imagePath == null || imagePath.isEmpty()) {
                result.error("INVALID_ARGS", "imagePath missing", null);
                return;
            }

            final boolean isCoffee = "coffee".equalsIgnoreCase(modelType);
            Log.d(TAG, "[predict] type=" + modelType + " isCoffee=" + isCoffee);

            // ── Input tensor metadata ───────────────────────────────────
            List<MSTensor> inputs = msModel.getInputs();
            if (inputs == null || inputs.isEmpty()) {
                result.error("NO_INPUTS", "No inputs", null);
                return;
            }
            MSTensor inputTensor = inputs.get(0);
            int[] shape     = inputTensor.getShape();
            int   dataType  = inputTensor.getDataType();
            int   elemCount = inputTensor.elementsNum();
            Log.d(TAG, "[predict] shape=" + java.util.Arrays.toString(shape)
                    + " dtype=" + dataType + " elems=" + elemCount);

            // Derive H, W, C (NHWC default)
            int imgH = 224, imgW = 224;
            if (shape != null && shape.length == 4) {
                if (shape[1] <= 4 && shape[3] > 16) {
                    // NCHW
                    imgH = shape[2]; imgW = shape[3];
                } else {
                    // NHWC
                    imgH = shape[1]; imgW = shape[2];
                }
            }

            // ── Decode + resize ─────────────────────────────────────────
            BitmapFactory.Options opts = new BitmapFactory.Options();
            opts.inPreferredConfig = Bitmap.Config.ARGB_8888;
            Bitmap raw = BitmapFactory.decodeFile(imagePath, opts);
            if (raw == null) {
                result.error("DECODE_FAILED", "Cannot decode", null);
                return;
            }
            Bitmap resized = Bitmap.createScaledBitmap(raw, imgW, imgH, true);
            raw.recycle();

            int[] pixels = new int[imgW * imgH];
            resized.getPixels(pixels, 0, imgW, 0, 0, imgW, imgH);
            resized.recycle();

            // ── Build input buffer ──────────────────────────────────────
            boolean isFloat = (dataType == 43 || dataType == 0);
            ByteBuffer inputBuf;

            if (isFloat) {
                inputBuf = ByteBuffer.allocateDirect(elemCount * 4);
                inputBuf.order(ByteOrder.nativeOrder());

                if (isCoffee) {
                    // Coffee: simple [0,1] normalization
                    for (int pixel : pixels) {
                        inputBuf.putFloat(((pixel >> 16) & 0xFF) / 255.0f);
                        inputBuf.putFloat(((pixel >>  8) & 0xFF) / 255.0f);
                        inputBuf.putFloat(( pixel        & 0xFF) / 255.0f);
                    }
                } else {
                    // Maize: ImageNet normalization
                    final float MR = 0.485f*255f, MG = 0.456f*255f, MB = 0.406f*255f;
                    final float SR = 0.229f*255f, SG = 0.224f*255f, SB = 0.225f*255f;
                    for (int pixel : pixels) {
                        inputBuf.putFloat((((pixel >> 16) & 0xFF) - MR) / SR);
                        inputBuf.putFloat((((pixel >>  8) & 0xFF) - MG) / SG);
                        inputBuf.putFloat(( (pixel        & 0xFF) - MB) / SB);
                    }
                }
            } else {
                inputBuf = ByteBuffer.allocateDirect(elemCount);
                inputBuf.order(ByteOrder.nativeOrder());
                for (int pixel : pixels) {
                    inputBuf.put((byte) ((pixel >> 16) & 0xFF));
                    inputBuf.put((byte) ((pixel >>  8) & 0xFF));
                    inputBuf.put((byte) ( pixel        & 0xFF));
                }
            }
            inputBuf.rewind();

            // ── Run inference ───────────────────────────────────────────
            inputTensor.setData(inputBuf);
            Log.d(TAG, "[predict] Running inference...");

            long t0 = System.currentTimeMillis();
            boolean ok = msModel.predict();
            long ms = System.currentTimeMillis() - t0;
            Log.d(TAG, "[predict] Done in " + ms + "ms, success=" + ok);

            if (!ok) {
                result.error("PREDICT_FAILED", "predict() returned false", null);
                return;
            }

            // ── Collect output ──────────────────────────────────────────
            float[] out = msModel.getOutputs().get(0).getFloatData();
            List<Double> preds = new ArrayList<>(out.length);
            for (float f : out) preds.add((double) f);

            Map<String, Object> res = new HashMap<>();
            res.put("predictions", preds);
            res.put("inferenceMs", (int) ms);
            result.success(res);

        } catch (Exception e) {
            Log.e(TAG, "[predict] Exception: " + e.getMessage(), e);
            result.error("PREDICT_ERROR", e.getMessage(), null);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private File copyAssetToFile(String assetPath) {
        try {
            String fileName = new File(assetPath).getName();
            File dest = new File(appContext.getFilesDir(), fileName);
            if (dest.exists() && dest.length() > 0) return dest;

            InputStream in;
            try {
                in = appContext.getAssets().open("flutter_assets/" + assetPath);
            } catch (IOException e1) {
                in = appContext.getAssets().open(assetPath);
            }

            try (FileOutputStream out = new FileOutputStream(dest)) {
                byte[] buf = new byte[8192];
                int n;
                while ((n = in.read(buf)) != -1) out.write(buf, 0, n);
            } finally { in.close(); }
            return dest;
        } catch (Exception e) {
            Log.e(TAG, "copyAsset: " + e.getMessage(), e);
            return null;
        }
    }

    private void releaseResources() {
        if (msModel != null) {
            try { msModel.free(); } catch (Exception ignored) {}
            msModel = null;
        }
        // No context to free — model.build() took ownership
    }

    private static class MainThreadResult implements Result {
        private final Result delegate;
        private final Handler handler;
        MainThreadResult(Result d, Handler h) { delegate = d; handler = h; }
        @Override public void success(Object r) { handler.post(() -> delegate.success(r)); }
        @Override public void error(String c, String m, Object d) {
            handler.post(() -> delegate.error(c, m, d));
        }
        @Override public void notImplemented() { handler.post(delegate::notImplemented); }
    }
}
