import numpy as np
import tensorflow as tf
import os

model_path = "../mobile_app/assets/models/yamnet.tflite"

def test_yamnet():
    print(f"Loading model... {model_path}")
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print("\nInput details:")
    for detail in input_details:
        print(f"Name: {detail['name']}, Shape: {detail['shape']}, Type: {detail['dtype']}")
        
    print("\nOutput details:")
    for detail in output_details:
        print(f"Name: {detail['name']}, Shape: {detail['shape']}, Type: {detail['dtype']}")
        
    # Generate dummy input: 15600 samples of pure silence (0s)
    input_shape = input_details[0]['shape']
    dummy_input = np.zeros(input_shape, dtype=np.float32)
    
    interpreter.set_tensor(input_details[0]['index'], dummy_input)
    interpreter.invoke()
    
    scores = interpreter.get_tensor(output_details[0]['index'])
    print(f"\nInference successful! Scores shape: {scores.shape}")
    
    # Try with random noise between -1 and 1
    np.random.seed(42)
    noise_input = np.random.uniform(-1, 1, input_shape).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], noise_input)
    interpreter.invoke()
    scores = interpreter.get_tensor(output_details[0]['index'])
    
    top_indices = np.argsort(scores[0])[::-1][:5]
    print(f"\nTop 5 indices for random noise: {top_indices}")
    print(f"Top 5 scores: {scores[0][top_indices]}")

if __name__ == "__main__":
    test_yamnet()
