#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include "include/api/model.h"
#include "include/api/context.h"
#include "include/api/types.h"
#include "include/api/serialization.h"

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "MindSporeJNI", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "MindSporeJNI", __VA_ARGS__)

using mindspore::Model;
using mindspore::Context;
using mindspore::ModelType;
using mindspore::MSTensor;

extern "C"
JNIEXPORT jlong JNICALL
Java_com_example_agri_1chain_MainActivity_initModelNative(JNIEnv *env, jobject thiz, jstring model_path) {
    const char *path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading model from: %s", path);

    auto context = std::make_shared<Context>();
    if (context == nullptr) {
        LOGE("Failed to create context.");
        env->ReleaseStringUTFChars(model_path, path);
        return 0;
    }

    auto &device_list = context->MutableDeviceInfo();
    auto cpu_device_info = std::make_shared<mindspore::CPUDeviceInfo>();
    cpu_device_info->SetEnableFP16(false);
    device_list.push_back(cpu_device_info);

    Model *model = new Model();
    auto ret = model->Build(std::string(path), ModelType::kMindIR, context);
    env->ReleaseStringUTFChars(model_path, path);

    if (ret != mindspore::kSuccess) {
        LOGE("Build model failed.");
        delete model;
        return 0;
    }

    LOGI("Model loaded successfully.");
    return reinterpret_cast<jlong>(model);
}

extern "C"
JNIEXPORT jfloatArray JNICALL
Java_com_example_agri_1chain_MainActivity_runInferenceNative(JNIEnv *env, jobject thiz, jlong model_ptr, jfloatArray input_data) {
    Model *model = reinterpret_cast<Model *>(model_ptr);
    if (model == nullptr) {
        LOGE("Model pointer is null.");
        return nullptr;
    }

    auto inputs = model->GetInputs();
    if (inputs.empty()) {
        LOGE("Model inputs are empty.");
        return nullptr;
    }

    auto in_tensor = inputs.front();
    jfloat *data = env->GetFloatArrayElements(input_data, nullptr);
    jsize length = env->GetArrayLength(input_data);

    // Get expected size in bytes
    if (in_tensor.DataSize() != length * sizeof(float)) {
        LOGE("Model input size mismatch. Expected: %zu bytes, Got: %zu bytes", in_tensor.DataSize(), length * sizeof(float));
        env->ReleaseFloatArrayElements(input_data, data, JNI_ABORT);
        return nullptr;
    }

    memcpy(in_tensor.MutableData(), data, in_tensor.DataSize());
    env->ReleaseFloatArrayElements(input_data, data, JNI_ABORT);

    std::vector<MSTensor> outputs;
    auto ret = model->Predict(inputs, &outputs);
    if (ret != mindspore::kSuccess) {
        LOGE("Predict failed.");
        return nullptr;
    }

    if (outputs.empty()) {
        LOGE("Model outputs are empty.");
        return nullptr;
    }

    auto out_tensor = outputs.front();
    float *out_data = reinterpret_cast<float *>(out_tensor.MutableData());
    int out_elements = out_tensor.ElementNum();

    jfloatArray result = env->NewFloatArray(out_elements);
    env->SetFloatArrayRegion(result, 0, out_elements, out_data);

    return result;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_agri_1chain_MainActivity_closeModelNative(JNIEnv *env, jobject thiz, jlong model_ptr) {
    Model *model = reinterpret_cast<Model *>(model_ptr);
    if (model != nullptr) {
        delete model;
        LOGI("Model closed.");
    }
}
