#!/bin/bash
# Activate Conda environment
export PATH="/opt/conda/envs/open3d_env/bin:$PATH"

# Activate the conda environment (if conda command is available in the shell)
source /opt/conda/etc/profile.d/conda.sh
conda activate open3d_env

# Step 1: ARAP Volume Tracking and Global Optimization
cd ./arap-volume-tracking
dotnet build -c release
dotnet ./bin/Client.dll ./config/max/config-basketball-max.xml
dotnet ./bin/Client.dll ./config/impr/config-basketball-impr.xml

# Step 2: Generate Reference Centers
cd ../TVMC
python ./get_reference_center.py --dataset basketball_player --num_frames 10 --num_centers 1995 --centers_dir ../arap-volume-tracking/data/basketball-output-max-2000/impr

# Step 3: Compute Transformations
python ./get_transformation.py --dataset basketball_player --num_frames 10 --num_centers 1995 --centers_dir ../arap-volume-tracking/data/basketball-output-max-2000/impr --firstIndex 11 --lastIndex 20

# Step 4: Mesh Processing
cd ../tvm-editing
dotnet new globaljson --sdk-version 5.0.408
dotnet build TVMEditor.sln --configuration Release --no-incremental
TVMEditor.Test/bin/Release/net5.0/TVMEditor.Test basketball 1 11 20 "./TVMEditor.Test/bin/Release/net5.0/Data/basketball_player_1995/" "./TVMEditor.Test/bin/Release/net5.0/output/basketball_player_1995/"

# Step 5: Extract Reference Mesh
cd ../TVMC
python ./extract_reference_mesh.py --dataset basketball_player --num_frames 10 --num_centers 1995 --inputDir ../tvm-editing/TVMEditor.Test/bin/Release/net5.0/output/basketball_player_1995/output/ --outputDir ../tvm-editing/TVMEditor.Test/bin/Release/net5.0/Data/basketball_player_1995/reference_mesh/ --firstIndex 11 --lastIndex 20

# Step 6: Deform Reference Mesh to Each Mesh in the Group
cd ../tvm-editing
TVMEditor.Test/bin/Release/net5.0/TVMEditor.Test basketball 2 11 20 "./TVMEditor.Test/bin/Release/net5.0/Data/basketball_player_1995" "./TVMEditor.Test/bin/Release/net5.0/output/basketball_player_1995/"

# Step 7: Compute Displacement Fields
cd ../TVMC
python ./get_displacements.py --dataset basketball_player --num_frames 10 --num_centers 1995 --target_mesh_path ../arap-volume-tracking/data/basketball_player --firstIndex 11 --lastIndex 20

# Step 8: Compression and Evaluation
python ./evaluation.py --dataset basketball_player --num_frames 10 --num_centers 1995 --firstIndex 11 --lastIndex 20 --fileNamePrefix basketball_player_fr0 --encoderPath ../draco/build/draco_encoder --decoderPath ../draco/build/draco_decoder --qp 10 --outputPath ./basketball_player_outputs