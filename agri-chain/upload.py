import os
import json
import shutil
from datetime import datetime

def deploy_to_firebase():
    """Deploy model to Firebase Hosting"""
    
    # Create deployment directory
    deploy_dir = 'firebase_deploy'
    models_dir = f'{deploy_dir}/public/models'
    
    # Clean and create directories
    if os.path.exists(deploy_dir):
        shutil.rmtree(deploy_dir)
    
    os.makedirs(models_dir, exist_ok=True)
    
    # Copy model files
    shutil.copy('assets/maize_disease.tflite', models_dir)
    shutil.copy('assets/labels.txt', models_dir)
    
    # Create firebase.json
    firebase_config = {
        "hosting": {
            "public": "public",
            "ignore": [
                "firebase.json",
                "**/.*",
                "**/node_modules/**"
            ],
            "headers": [
                {
                    "source": "**",
                    "headers": [
                        {"key": "Access-Control-Allow-Origin", "value": "*"},
                        {"key": "Cache-Control", "value": "public, max-age=3600"}
                    ]
                }
            ]
        }
    }
    
    with open(f'{deploy_dir}/firebase.json', 'w') as f:
        json.dump(firebase_config, f, indent=2)
    
    # Create version file
    version_info = {
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
        "model_size": os.path.getsize('assets/maize_disease.tflite'),
        "description": "Maize Disease Detection Model"
    }
    
    with open(f'{models_dir}/version.json', 'w') as f:
        json.dump(version_info, f, indent=2)
    
    print("✅ Model prepared for Firebase deployment")
    print(f"📁 Deployment directory: {deploy_dir}")
    print("\n📋 To deploy:")
    print(f"cd {deploy_dir}")
    print("firebase deploy --only hosting")
    
    return deploy_dir

if __name__ == "__main__":
    deploy_to_firebase()