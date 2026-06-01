# VisionXAI Model Training Capsule Built using Codeocean

## Project Building and Running

### Build image

```cmd
cd environment && docker build . --tag aed8529a-ded6-4419-ad11-4a8ce0dd580b
```

### Run image

For Windows Command Prompt (`cmd`):

```cmd
docker run --platform linux/amd64 --rm --gpus all --workdir /code --volume "%cd%/data":/data --volume "%cd%/code":/code --volume "%cd%/results":/results aed8529a-ded6-4419-ad11-4a8ce0dd580b bash run
```

For PowerShell:

```powershell
docker run --platform linux/amd64 --rm --gpus all --workdir /code --volume "${PWD}/data:/data" --volume "${PWD}/code:/code" --volume "${PWD}/results:/results" aed8529a-ded6-4419-ad11-4a8ce0dd580b bash run
```

> [!TIP]
> If your system does not have an NVIDIA GPU or the NVIDIA Container Toolkit is not configured, remove the `--gpus all` flag from the command to run on CPU.

## Running Jupyter for Development

1. **Start a Docker Container:**
   Start a container from the image using the following command:

   **Command Prompt (cmd):**

   ```cmd
   docker run -p 8888:8888 -it --platform linux/amd64 --rm --gpus all --workdir /code --volume "%cd%/data":/data --volume "%cd%/code":/code --volume "%cd%/results":/results aed8529a-ded6-4419-ad11-4a8ce0dd580b /bin/bash
   ```

   **PowerShell:**

   ```powershell
   docker run -p 8888:8888 -it --platform linux/amd64 --rm --gpus all --workdir /code --volume "${PWD}/data:/data" --volume "${PWD}/code:/code" --volume "${PWD}/results:/results" aed8529a-ded6-4419-ad11-4a8ce0dd580b /bin/bash
   ```

   This command will start a new container based on the image tagged as `aed8529a-ded6-4419-ad11-4a8ce0dd580b` and open an interactive shell (`/bin/bash`) within the container.

2. **Activate Miniconda Environment:**
   Before launching the Jupyter Notebook server, ensure that you have activated your Miniconda environment. If you haven't activated it yet, you can do so by running:

   ```bash
   source /opt/conda/bin/activate
   ```

   This command activates the Miniconda environment.

3. **Launch Jupyter Notebook:**
   Once your Miniconda environment is activated, you can launch the Jupyter Notebook server in Command Line by running:

   ```bash
   jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root
   ```

   This command will start the Jupyter Notebook server and open a web browser with the Jupyter Dashboard, where you can navigate your files and create or open notebooks.

4. **Access Jupyter Notebook:**
   After running the `jupyter notebook` command, you should see output in your terminal with a URL that starts with `http://127.0.0.1:8888`. Open this URL in your web browser, and you should be directed to the Jupyter Dashboard, where you can create or open notebooks.

---

## TFLite Model Export for On-Device Flutter Inference

To enable real-time, on-device image captioning and attention visualization, the trained TensorFlow models are exported into TensorFlow Lite (TFLite) format.

### Export Pipeline & Scripts

1. **Jupyter Notebook Integration (`code/bangla_image_caption.ipynb`)**:
   - TFLite conversion blocks are appended at the end of the model training steps.
2. **Standalone TFLite Export Script (`code/export_tflite.py`)**:
   - Loads the best training checkpoint.
   - Reconstructs the vocabulary tokenizer.
   - Wraps the model components into concrete signatures (`Feature Extractor` and `Decoder Step Wrapper`) to support static input shapes required for on-device inference.
   - Compiles and exports the models to TFLite format and verifies inputs/outputs.

### Exported Artifacts (Saved under `/results`)

- **`feature_extractor.tflite`** (87.1 MB): Extractor model taking an image input of size `[1, 299, 299, 3]` and producing visual grid features of size `[1, 8, 8, 2048]`.
- **`decoder.tflite`** (41.8 MB): RNN step wrapper combining the CNN encoder projection and RNN decoder step with dynamic state tracking (`dec_input`, `image_features`, `hidden`).
- **`vocab.json`** (85.9 KB): Token vocabulary JSON matching word to index token mapping (necessary for pre-processing/post-processing in Flutter).

### Verification and Tensor Shapes

The models have been verified in the environment container with the following signature properties:

- **Feature Extractor**:
  - Inputs: `[1, 299, 299, 3]` (`float32`)
  - Outputs: `[1, 8, 8, 2048]` (`float32`)
- **Decoder Step Wrapper**:
  - Inputs:
    - `serving_default_image_features:0`: `[1, 64, 2048]` (`float32`)
    - `serving_default_hidden:0`: `[1, 512]` (`float32`)
    - `serving_default_dec_input:0`: `[1, 1]` (`int32`)
  - Outputs:
    - `StatefulPartitionedCall:0` (Attention Weights): `[1, 64, 1]` (`float32`)
    - `StatefulPartitionedCall:1` (Next Hidden State): `[1, 512]` (`float32`)
    - `StatefulPartitionedCall:2` (Vocabulary Logits): `[1, 10001]` (`float32`)
