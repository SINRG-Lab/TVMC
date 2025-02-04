# **TVMC: Time-Varying Mesh Compression Using Volume-Tracked Reference Meshes**

Guodong Chen, Filip Hácha, Libor Váša, Mallesham Dasari

![alt text](https://github.com/frozzzen3/TVMC/blob/main/images/TVMC-workflow.png?raw=true)

This repository contains the official authors implementation associated with the paper **"TVMC: Time-Varying Mesh Compression Using Volume-Tracked Reference Meshes"**, which can be found [here](https://arxiv.org/abs/2407.02457), accepted by [2025 ACM MMSys](https://2025.acmmmsys.org/).

## Running with Docker

Follow these steps to build and run the Docker image:

### Step 1: Build the Docker Image

To begin, build the Docker image from the provided Dockerfile:

```
docker build -t tvmc-linux .
```

### Step 2: Run the Docker Image

After building the image, run the Docker container with the following command:

```
docker run --rm -it tvmc-linux
```

### Step 3: Run the Pipeline Script

Once inside the Docker container, grant execute permissions to the `run_pipeline.sh` script and execute it:

```
chmod +x run_pipeline.sh
sudo ./run_pipeline.sh
```

The pipeline will start, and the required tasks will be executed sequentially.



---

## Running TVMC on Your Own Machine

If you want to run TVMC on your own machine using your own dataset, here’s how you can set it up.

(Provide the detailed steps here for running the pipeline outside of Docker)

## Step 0:

Install .Net 7.0

For Linux:

```
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update && \  sudo apt-get install -y dotnet-sdk-7.0
sudo apt-get update && \  sudo apt-get install -y aspnetcore-runtime-7.0
```

```
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh

conda create -n open3d_env python==3.8 numpy open3d==0.18.0 scikit-learn scipy trimesh==4.1.0 -c conda-forge
echo 'export PATH="$HOME/miniconda3/bin:$PATH"' 

~/.bashrc source ~/.bashrc
conda init
source ~/.bashrc
conda activate open3d_env
```



For windows you can use anaconda.

Clone this project:

```
git clone https://github.com/frozzzen3/TVMC.git
```

## Step 1: As-Rigid-As-Possible (ARAP) Volume Tracking

ARAP volume tracking is written in C# and .NET 7.0

Navigate to the root directory:

```
cd ./arap-volume-tracking
```

Build the project:

```
dotnet build -c release
```

Run the tracking process:

```
dotnet ./bin/Client.dll ./config/max/config-basketball-max.xml
```

Volume tracking results are saved in the `<outDir>` folder:

- `.xyz` files: coordinates of volume centers
- `.txt` files: transformations of centers between frames

### Global Optimization (Optional but Recommended)

Global optimization refines volume centers by removing abnormal volume centers and adjusting positions for the remains to reduce distortions.

```
dotnet ./bin/Client.dll ./config/impr/config-basketball-impr.xml
```

Results are stored in `<outDir>/impr`.

Additional time-varying mesh sequences are available in `./arap-volume-tracking/data`. Configuration files are in `./arap-volume-tracking/config`. Different tracking modes (`./iir`, `./impr`, `./max`) use distinct configurations. More details [here](https://github.com/frozzzen3/TVMC/blob/main/arap-volume-tracking/README.md).

To run ARAP volume tracking on a custom dataset:

```
dotnet ./bin/client.dll <config_file.xml>
```

## Step 2: Generate Reference Centers Using Multi-Dimensional Scaling (MDS)

Navigate to TVMC root:

```
cd ../TVMC
```

Run the MDS script:

```
python ./get_reference_center.py --dataset basketball_player --num_frames 10 --num_centers 1995 --centers_dir ../arap-volume-tracking/data/basketball-output-max-2000/impr
```

The number of centers (`--num_centers`) must match the global optimization results. Output is stored in `./arap-volume-tracking/data/basketball-output-max-2000/impr/reference/reference_centers_aligned.xyz`.

If the number of volume centers is large, experiment with different `random_state` values for better results.

## Step 3: Compute Transformation Dual Quaternions

Then, we compute the transformations for each center, mapping their original positions to the reference space, along with their inverses. These transformations are then used to deform the mesh surface based on the movement of volume centers.

```
python ./get_transformation.py --dataset basketball_player --num_frames 10 --num_centers 1995 --centers_dir ../arap-volume-tracking/data/basketball-output-max-2000/impr --firstIndex 11 --lastIndex 20
```

## Step 4: Create Volume-Tracked, Self-Contact-Free Reference Mesh

Switch to .NET 5.0.

```
sudo apt-get install -y dotnet-sdk-5.0
sudo apt-get install -y aspnetcore-runtime-5.0
dotnet new globaljson --sdk-version 5.0.408
```

Navigate to the `tvm-editing` directory and build:

```
cd ../tvm-editing
dotnet build TVMEditor.sln --configuration Release --no-incremental
```

Run the mesh deformation:

```
TVMEditor.Test/bin/Release/net5.0/TVMEditor.Test.exe basketball 1 11 20 "./TVMEditor.Test/bin/Release/net5.0/Data/basketball_player_1995/" "./TVMEditor.Test/bin/Release/net5.0/output/basketball_player_1995/"
```

for Linux:

```
TVMEditor.Test/bin/Release/net5.0/TVMEditor.Test basketball 1 11 20 "./TVMEditor.Test/bin/Release/net5.0/Data/basketball_player_1995/" "./TVMEditor.Test/bin/Release/net5.0/output/basketball_player_1995/"
```



Navigate to TVMC root again:

```
cd ../TVMC
```

Extract the reference mesh:

```
python ./extract_reference_mesh.py --dataset basketball_player --num_frames 10 --num_centers 1995 --inputDir ../tvm-editing/TVMEditor.Test/bin/Release/net5.0/output/basketball_player_1995/output/ --outputDir ../tvm-editing/TVMEditor.Test/bin/Release/net5.0/Data/basketball_player_1995/reference_mesh/ --firstIndex 11 --lastIndex 20
```

## Step 5: Deform Reference Mesh to Each Mesh in the Group

Navigate to the `tvm-editing` directory,

```
cd ../tvm-editing
```

Then run:

```
TVMEditor.Test/bin/Release/net5.0/TVMEditor.Test.exe basketball 2 11 20 "./TVMEditor.Test/bin/Release/net5.0/Data/basketball_player_1995" "./TVMEditor.Test/bin/Release/net5.0/output/basketball_player_1995/"
```

For Linux:

```
TVMEditor.Test/bin/Release/net5.0/TVMEditor.Test basketball 2 11 20 "./TVMEditor.Test/bin/Release/net5.0/Data/basketball_player_1995" "./TVMEditor.Test/bin/Release/net5.0/output/basketball_player_1995/"
```



## Step 6: Compute Displacement Fields

Navigate to TVMC root again:

```
cd ../TVMC
```

```
python ./get_displacements.py --dataset basketball_player --num_frames 10 --num_centers 1995 --target_mesh_path ../arap-volume-tracking/data/basketball_player --firstIndex 11 --lastIndex 20
```

The displacement fields are stored as `.ply` files. For compression, Draco is used to encode both the reference mesh and displacements.



Tips: So far, we've got everything we need for a group of time-varying mesh compression (A self-contact-free reference mesh and displacement fields). You can use any other compression methods to deal with them. For example, you may use video coding to compress displacements to get even better compression performance.

## Step 7: Compression and Evaluation

Clone and build Draco:

```
git clone https://github.com/google/draco.git
cd ./draco
mkdir build
cd build
```

On Windows:

```
cmake ../ -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release
```

On Linux:

```
cmake ../
make
```

On Mac OS X, run the following command to generate Xcode projects:

```
$ cmake ../ -G Xcode
```

Draco paths:

- Encoder: `./draco/build/Release/draco_encoder.exe`
- Decoder: `./draco/build/Release/draco_decoder.exe`

Navigate to TVMC root again:

```
cd ./TVMC
```

Run the evaluation:

```
python ./evaluation.py --dataset basketball_player --num_frames 10 --num_centers 1995 --firstIndex 11 --lastIndex 20 --fileNamePrefix basketball_player_fr0 --encoderPath ../draco/build/Release/draco_encoder.exe --decoderPath ../draco/build/Release/draco_decoder.exe --qp 10 --outputPath ./basketball_player_outputs
```

For Linux:

```
python ./evaluation.py --dataset basketball_player --num_frames 10 --num_centers 1995 --firstIndex 11 --lastIndex 20 --fileNamePrefix basketball_player_fr0 --encoderPath ../draco/build/draco_encoder --decoderPath ../draco/build/draco_decoder --qp 10 --outputPath ./basketball_player_outputs
```

