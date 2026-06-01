import tensorflow as tf
import numpy as np
import json
import os
import pickle
import sys

# Add the 'code' directory to sys.path so we can import caption_parsers
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from caption_parsers import JSONCaptionParser

# Paths
if sys.platform.startswith('win'):
    ANNOTATION_FILE = r'd:\courses\graduate project\xai new project\codeocean project\capsule-5653931\data\rxxch9vw59-2\captions.json'
    IMAGE_DIR = r'd:\courses\graduate project\xai new project\codeocean project\capsule-5653931\data\rxxch9vw59-2\images'
    RESULTS_DIR = r'd:\courses\graduate project\xai new project\codeocean project\capsule-5653931\results'
else:
    ANNOTATION_FILE = '/data/rxxch9vw59-2/captions.json'
    IMAGE_DIR = '/data/rxxch9vw59-2/images'
    RESULTS_DIR = '/results'

BEST_MODEL_CKPT = tf.train.latest_checkpoint(os.path.join(RESULTS_DIR, 'best_model'))
if BEST_MODEL_CKPT is None:
    # Fallback to train checkpoint directory if best_model is empty
    BEST_MODEL_CKPT = tf.train.latest_checkpoint(os.path.join(RESULTS_DIR, 'train'))

# 1. Parse Captions & Recreate Tokenizer
print("Parsing captions...")
parser = JSONCaptionParser()
caption_mapping = parser.extract(
    file_path=ANNOTATION_FILE,
    images_path=IMAGE_DIR,
    validate_images=False # Avoid expensive disk check during export
)

train_captions = []
for image_path, captions in caption_mapping.items():
    train_captions.extend([f"<start> {cap} <end>" for cap in captions])

print(f"Total captions parsed: {len(train_captions)}")

print("Recreating tokenizer...")
top_k = 10000
tokenizer = tf.keras.preprocessing.text.Tokenizer(
    num_words=top_k,
    oov_token="<unk>",
    filters='!"#$%&()*+.,-/:;=?@[\\]^_`{|}~ '
)
tokenizer.fit_on_texts(train_captions)
tokenizer.word_index['<pad>'] = 0
tokenizer.index_word[0] = '<pad>'

# Save tokenizer.pkl
tokenizer_path = os.path.join(RESULTS_DIR, 'tokenizer.pkl')
with open(tokenizer_path, 'wb') as tok_f:
    pickle.dump(tokenizer, tok_f)
print(f"Tokenizer saved to {tokenizer_path}")

# Save vocab.json
vocab_json_path = os.path.join(RESULTS_DIR, 'vocab.json')
with open(vocab_json_path, 'w', encoding='utf-8') as f:
    json.dump(tokenizer.word_index, f, ensure_ascii=False, indent=4)
print(f"Vocabulary JSON saved to {vocab_json_path}")

# 2. Recreate Model Architecture
embedding_dim = 256
units = 512
vocab_size = top_k + 1

class BahdanauAttention(tf.keras.Model):
    def __init__(self, units):
        super(BahdanauAttention, self).__init__()
        self.W1 = tf.keras.layers.Dense(units)
        self.W2 = tf.keras.layers.Dense(units)
        self.V = tf.keras.layers.Dense(1)

    def call(self, features, hidden):
        hidden_with_time_axis = tf.expand_dims(hidden, 1)
        attention_hidden_layer = (tf.nn.tanh(self.W1(features) +
                                             self.W2(hidden_with_time_axis)))
        score = self.V(attention_hidden_layer)
        attention_weights = tf.nn.softmax(score, axis=1)
        context_vector = attention_weights * features
        context_vector = tf.reduce_sum(context_vector, axis=1)
        return context_vector, attention_weights

class CNN_Encoder(tf.keras.Model):
    def __init__(self, embedding_dim):
        super(CNN_Encoder, self).__init__()
        self.fc = tf.keras.layers.Dense(embedding_dim)

    def call(self, x):
        x = self.fc(x)
        x = tf.nn.relu(x)
        return x

class RNN_Decoder(tf.keras.Model):
    def __init__(self, embedding_dim, units, vocab_size):
        super(RNN_Decoder, self).__init__()
        self.units = units
        self.embedding = tf.keras.layers.Embedding(vocab_size, embedding_dim)
        self.gru = tf.keras.layers.GRU(self.units,
                                       return_sequences=True,
                                       return_state=True,
                                       recurrent_initializer='glorot_uniform')
        self.fc1 = tf.keras.layers.Dense(self.units)
        self.fc2 = tf.keras.layers.Dense(vocab_size)
        self.attention = BahdanauAttention(self.units)

    def call(self, x, features, hidden):
        context_vector, attention_weights = self.attention(features, hidden)
        x = self.embedding(x)
        x = tf.concat([tf.expand_dims(context_vector, 1), x], axis=-1)
        with tf.device('/device:CPU:0'):
            output, state = self.gru(x)
        x = self.fc1(output)
        x = tf.reshape(x, (-1, x.shape[2]))
        x = self.fc2(x)
        return x, state, attention_weights

encoder = CNN_Encoder(embedding_dim)
decoder = RNN_Decoder(embedding_dim, units, vocab_size)
optimizer = tf.keras.optimizers.Adam()

# Restore checkpoint
print(f"Restoring checkpoint from {BEST_MODEL_CKPT}...")
ckpt = tf.train.Checkpoint(encoder=encoder, decoder=decoder, optimizer=optimizer)
ckpt.restore(BEST_MODEL_CKPT).expect_partial()
print("Restored successfully!")

# 3. Export Image Feature Extractor
print("Loading InceptionV3 feature extractor...")
image_model = tf.keras.applications.InceptionV3(include_top=False, weights='imagenet')
new_input = image_model.input
hidden_layer = image_model.layers[-1].output
image_features_extract_model = tf.keras.Model(new_input, hidden_layer)

class FeatureExtractorWrapper(tf.Module):
    def __init__(self, feature_model):
        super(FeatureExtractorWrapper, self).__init__()
        self.feature_model = feature_model

    @tf.function(input_signature=[
        tf.TensorSpec(shape=[1, 299, 299, 3], dtype=tf.float32, name="input_image")
    ])
    def __call__(self, input_image):
        return self.feature_model(input_image)

tflite_feature_extractor_path = os.path.join(RESULTS_DIR, 'feature_extractor.tflite')
print("Converting Feature Extractor to TFLite...")
wrapper_fe = FeatureExtractorWrapper(image_features_extract_model)
fe_converter = tf.lite.TFLiteConverter.from_concrete_functions([
    wrapper_fe.__call__.get_concrete_function()
], wrapper_fe)
fe_tflite = fe_converter.convert()
with open(tflite_feature_extractor_path, 'wb') as f:
    f.write(fe_tflite)
print(f"✅ Feature extractor TFLite saved to {tflite_feature_extractor_path}")

# 4. Export Decoder step (including CNN Encoder step)
class TFLiteDecoderWrapper(tf.Module):
    def __init__(self, encoder, decoder):
        super(TFLiteDecoderWrapper, self).__init__()
        self.encoder = encoder
        self.decoder = decoder

    @tf.function(input_signature=[
        tf.TensorSpec(shape=[1, 1], dtype=tf.int32, name="dec_input"),
        tf.TensorSpec(shape=[1, 64, 2048], dtype=tf.float32, name="image_features"),
        tf.TensorSpec(shape=[1, 512], dtype=tf.float32, name="hidden")
    ])
    def __call__(self, dec_input, image_features, hidden):
        encoded_features = self.encoder(image_features)
        predictions, next_hidden, attention_weights = self.decoder(dec_input, encoded_features, hidden)
        return {
            "predictions": predictions,
            "next_hidden": next_hidden,
            "attention_weights": attention_weights
        }

tflite_decoder_path = os.path.join(RESULTS_DIR, 'decoder.tflite')
print("Converting Decoder step wrapper to TFLite...")
wrapper = TFLiteDecoderWrapper(encoder, decoder)
dec_converter = tf.lite.TFLiteConverter.from_concrete_functions([
    wrapper.__call__.get_concrete_function()
], wrapper)
dec_converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
    tf.lite.OpsSet.SELECT_TF_OPS
]
dec_tflite = dec_converter.convert()
with open(tflite_decoder_path, 'wb') as f:
    f.write(dec_tflite)
print(f"✅ Decoder step wrapper TFLite saved to {tflite_decoder_path}")

# 5. Verification
print("Verifying feature extractor model...")
interpreter = tf.lite.Interpreter(model_path=tflite_feature_extractor_path)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
print("Feature Extractor Inputs:", input_details[0]['shape'], input_details[0]['dtype'])
print("Feature Extractor Outputs:", output_details[0]['shape'], output_details[0]['dtype'])

print("Verifying decoder wrapper model...")
interpreter_dec = tf.lite.Interpreter(model_path=tflite_decoder_path)
interpreter_dec.allocate_tensors()
dec_inputs = interpreter_dec.get_input_details()
dec_outputs = interpreter_dec.get_output_details()
print("Decoder Inputs:")
for detail in dec_inputs:
    print(f"  {detail['name']}: {detail['shape']} ({detail['dtype']})")
print("Decoder Outputs:")
for detail in dec_outputs:
    print(f"  {detail['name']}: {detail['shape']} ({detail['dtype']})")

print("🎉 Conversion and verification completed successfully!")
