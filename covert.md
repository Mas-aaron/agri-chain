📱 MindSpore Lite Conversion Guide - Complete README
markdown
# AgriChain MindSpore Lite Models for Mobile Deployment

## 📋 Overview
This document outlines the complete process of converting AgriChain disease detection models from MindIR format to MindSpore Lite (`.ms`) format for offline mobile deployment on smartphones.

## 📊 Model Information

### Converted Models
| Model | Original Format | Converted Format | Classes | Original Size | Converted Size |
|-------|----------------|-------------------|---------|---------------|----------------|
| Maize Disease | `maize_disease.mindir` | `maize_model.ms` | 4 | 9.3 MB | 8.9 MB |
| Coffee Disease | `coffee_disease.mindir` | `coffee_model.ms` | 3 | 9.3 MB | 8.9 MB |

### Class Labels
**Maize Classes (4):**
0: Gray_Leaf_Spot
1: Common_Rust
2: Blight
3: Healthy

text

**Coffee Classes (3):**
0: phoma
1: leaf rust
2: Health leaves

text

### Model Specifications
| Parameter | Value |
|-----------|-------|
| Input Shape | `[1, 3, 224, 224]` |
| Input Format | RGB, normalized to [0,1] |
| Output Shape | `[1, num_classes]` |
| Data Type | Float32 |
| Inference Time | ~30-50ms on modern mobile devices |

---

## 🔧 Conversion Environment Setup

### System Requirements
- **OS**: Windows 10/11 with WSL2 (Ubuntu 24.04 LTS)
- **CPU**: Any modern x86_64 processor
- **RAM**: 4GB minimum (8GB recommended)
- **Storage**: 500MB free space
- **GPU**: Not required (conversion is CPU-only)

### Step 1: Install WSL2 (if not already installed)
```powershell
# In PowerShell (Administrator)
wsl --install -d Ubuntu-24.04
Step 2: Create Unix User Account
During Ubuntu installation, create a user:

Username: Use lowercase only (e.g., masendi)

Password: [Choose a secure password]

Step 3: Download MindSpore Lite Converter
bash
# In WSL Ubuntu terminal
cd ~
wget https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.3.0/MindSpore/lite/release/linux/x86_64/mindspore-lite-2.3.0-linux-x64.tar.gz
Step 4: Extract Converter
bash
tar -xzf mindspore-lite-2.3.0-linux-x64.tar.gz
🔄 Model Conversion Process
Step 1: Copy Models from Windows to WSL
bash
# Copy model files from Windows Downloads
cp /mnt/c/Users/[YourUsername]/Downloads/maize_disease.mindir ~/
cp /mnt/c/Users/[YourUsername]/Downloads/coffee_disease.mindir ~/

# Verify files were copied
ls -la *.mindir
Step 2: Set Library Path (CRITICAL!)
bash
# Required to find converter libraries
export LD_LIBRARY_PATH=~/mindspore-lite-2.3.0-linux-x64/tools/converter/lib:$LD_LIBRARY_PATH
Step 3: Convert Maize Model
bash
~/mindspore-lite-2.3.0-linux-x64/tools/converter/converter/converter_lite \
  --fmk=MINDIR \
  --modelFile=maize_disease.mindir \
  --outputFile=maize_model \
  --inputShape="input:1,3,224,224"
Step 4: Convert Coffee Model
bash
~/mindspore-lite-2.3.0-linux-x64/tools/converter/converter/converter_lite \
  --fmk=MINDIR \
  --modelFile=coffee_disease.mindir \
  --outputFile=coffee_model \
  --inputShape="input:1,3,224,224"
Step 5: Verify Conversion Success
bash
# Check for .ms files
ls -la *.ms
Expected output shows files with -r-------- permissions and sizes ~8.9 MB.

Success Indicator: Look for CONVERT RESULT SUCCESS:0 in the conversion output.

Step 6: Copy Converted Models Back to Windows
bash
# Copy to Windows Downloads folder
cp maize_model.ms coffee_model.ms /mnt/c/Users/[YourUsername]/Downloads/

# Verify copy
ls -la /mnt/c/Users/[YourUsername]/Downloads/*.ms
⚠️ Common Issues and Solutions
Issue 1: Missing Library Error
Error: error while loading shared libraries: libmindspore_converter.so: cannot open shared object file
Solution: Set library path before running converter

bash
export LD_LIBRARY_PATH=~/mindspore-lite-2.3.0-linux-x64/tools/converter/lib:$LD_LIBRARY_PATH
Issue 2: Input Shape Error
Error: shape size must not be less than 2
Solution: Use correct input shape format with input name

bash
--inputShape="input:1,3,224,224"  # Correct format
--inputShape=1,3,224,224           # Wrong format
Issue 3: WSL Mount Error
Error: An error occurred mounting the distribution disk
Solution:

powershell
# In PowerShell (Admin)
wsl --shutdown
wsl ~
Issue 4: Permission Denied When Copying
Solution: Check Windows mount permissions

bash
# Test write access
touch /mnt/c/Users/[YourUsername]/Downloads/test.txt
Issue 5: Warnings During Conversion
Issue: Long lists of warning messages during conversion
Explanation: These are normal optimization messages and can be safely ignored. Only look for CONVERT RESULT SUCCESS:0.