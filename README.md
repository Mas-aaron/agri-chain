# 🌽 AgriChain: AI-Driven Sustainable Agriculture Ecosystem

AgriChain is an integrated ecosystem leveraging **Huawei MindSpore**, **Blockchain (Hyperledger Fabric)**, and **IoT** to empower smallholder farmers. It provides pre-symptomatic crop disease detection, yield prediction, and a decentralized marketplace to secure fair prices using "Future Harvest Contracts".

---

## 📂 Repository Structure

The project is divided into five core modules:

- `/agri-chain` - The main Flutter mobile application (Farmer & Buyer App)
- `/backend/backend` - Python FastAPI backend (Yield prediction API, Services)
- `/blockchain/agri-yield-blockchain` - Huawei BCS / Hyperledger Fabric Smart Contracts (Go)
- `/mindspore_lite_flutter` - Custom Flutter plugin wrapping the MindSpore C++ engine
- `/rover` - ESP32 firmware for the autonomous field-mapping rover

---

## 🧠 1. AI Training & MindSpore Models

We provide Jupyter Notebooks to reproduce the MindSpore MobileNetV2 models used for Maize and Coffee disease detection.

### Reproduction Steps
1. Upload the dataset to Huawei Cloud OBS or local path `/data/agrichain/dataset.zip`.
2. Open `mindspore_disease_training2.ipynb` in your Jupyter/ModelArts environment.
3. Install dependencies: `pip install mindspore mindvision`.
4. Run all notebook cells. The notebook will:
   - Preprocess and augment the imagery.
   - Train a custom MobileNetV2 instance using `nn.SoftmaxCrossEntropyWithLogits`.
   - Output validation accuracy graphs.
   - Export `.mindir` models and convert them to optimized `.ms` MindSpore Lite formats for Flutter.

*Saved model weights (`.ms` and `.tflite`) are pre-bundled in `agri-chain/assets/models/` for immediate mobile inference.*

---

## 📱 2. Mobile App (Flutter)

The mobile app includes the UI, on-device AI inference via our custom MindSpore Lite plugin, and blockchain wallet integration.

### Setup
1. Ensure Flutter is installed (`flutter doctor`).
2. Navigate to the app directory:
   ```bash
   cd agri-chain
   flutter pub get
   ```
3. Run the application on a physical Android device (MindSpore Lite requires ARM64 architecture):
   ```bash
   flutter run --release
   ```

> **Note:** On-device inference runs locally. The app will request Camera permissions upon the first disease scan.

---

## ⚙️ 3. Backend & Yield Intelligence (Python / FastAPI)

The backend handles the predictive yield model (Linear Regression/DNN) and routes traffic to the Huawei Blockchain Service.

### Setup
1. Navigate to the backend directory:
   ```bash
   cd backend/backend
   ```
2. Create a virtual environment and install dependencies:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```
3. Start the FastAPI server:
   ```bash
   uvicorn agrichain.main:app --host 0.0.0.0 --port 8000 --reload
   ```

---

## 🔗 4. Blockchain (Huawei BCS / Hyperledger Fabric)

The ecosystem uses a permissioned ledger to tokenize predicted yields into bankable assets.

### Setup
1. Smart contracts are located in `/blockchain/agri-yield-blockchain/2-chaincode/go`.
2. To deploy to Huawei BCS, follow the instructions in `blockchain/agri-yield-blockchain/1-bcs-deployment/README.md`.
3. Ensure the backend has access to the generated `bcs-certs/` to communicate with the gateway.

---

## 🤖 5. IoT Rover

The ESP32-based rover provides ground-truth GPS mapping of the farm fields and soil analysis.
1. Open `rover/rover.ino` in the Arduino IDE.
2. Select the **AI Thinker ESP32-CAM** or generic **ESP32 Dev Module** board.
3. Compile and flash via USB.

---

## 📊 Evaluation & Inference Logs
Run the provided benchmarking script (`generate_inference_logs.py`) to generate throughput and latency metrics for the exported models. See `inference_logs.txt` for the latest runtime performance results on edge hardware.
