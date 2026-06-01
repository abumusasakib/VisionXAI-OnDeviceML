import tensorflow as tf
import os

results_dir = "/results"
fe_path = os.path.join(results_dir, "feature_extractor.tflite")
dec_path = os.path.join(results_dir, "decoder.tflite")

print("--- Verifying Feature Extractor ---")
fe_interpreter = tf.lite.Interpreter(model_path=fe_path)
fe_interpreter.allocate_tensors()
fe_inputs = fe_interpreter.get_input_details()
fe_outputs = fe_interpreter.get_output_details()

print(f"Feature Extractor Input: {fe_inputs[0]['name']} - Shape: {fe_inputs[0]['shape']} - Dtype: {fe_inputs[0]['dtype']}")
print(f"Feature Extractor Output: {fe_outputs[0]['name']} - Shape: {fe_outputs[0]['shape']} - Dtype: {fe_outputs[0]['dtype']}")

print("\n--- Verifying Decoder ---")
dec_interpreter = tf.lite.Interpreter(model_path=dec_path)
dec_interpreter.allocate_tensors()
dec_inputs = dec_interpreter.get_input_details()
dec_outputs = dec_interpreter.get_output_details()

print("Decoder Inputs:")
for detail in dec_inputs:
    print(f"  {detail['name']}: {detail['shape']} - Dtype: {detail['dtype']}")

print("Decoder Outputs:")
for detail in dec_outputs:
    print(f"  {detail['name']}: {detail['shape']} - Dtype: {detail['dtype']}")

print("\nAll models verified successfully!")
