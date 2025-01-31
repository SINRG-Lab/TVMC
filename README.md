# **TVMC: Time-Varying Mesh Compression Using Volume-Tracked Reference Meshes**

Guodong Chen, Filip Hácha, Libor Váša, Mallesham Dasari

![alt text](https://github.com/frozzzen3/TVMC/blob/main/images/TVMC-workflow.png?raw=true)

This repository contains the official authors implementation associated with the paper **"TVMC: Time-Varying Mesh Compression Using Volume-Tracked Reference Meshes"**, which can be found [here] (to be added), accepted by [2025 ACM MMSys](https://2025.acmmmsys.org/).

⚠️ **Note: This is NOT the final version!** ⚠️

## Step-by-step Tutorial

I'll use `basketball player` dataset from [TDMD](https://multimedia.tencent.com/resources/tdmd) to show the whole pipeline.

## Step 1: As-rigid-as-possible Volume tracking

go to the root `cd ./arap-volume-tracking `

build 

``` 
dotnet build -c release
```

The build application is in `./bin` folder.

```
dotnet ./bin/client.dll ./config/max/config-basketball-max.xml
```

Now, you can find volume tracking results in the `<outDir>` folder.

`.xyz` files represent the coordinates of each centers 

`.txt` files represent the transformation for each centers between frames 

Global optimization mode can only be adopted after getting volume centers, it will try to remove a certain number of abnormal volume centers and adjust positions of the remains. Although it is optional, we do recommend to do this step to get a better set of volume centers, which can significantly reduce distortions for the following steps.

```
dotnet ./bin/client.dll ./config/impr/config-basketball-impr.xml
```

You can find the optimized volume tracking results in the `<outDir>/impr` folder.



Some other time-varying mesh sequences are stored in `./arap-volume-tracking/data`.

Configuration files can be found in `./arap-volume-tracking/config`

You may be curious about why there are three folders, actually `./iir` `./impr` `./max` represent different configuration files for three tracking modes, please find more details and examples [here](https://github.com/frozzzen3/TVMC/blob/main/arap-volume-tracking/README.md).

To run ARAP volume tracking on your own dataset,  create configuration file then execute

```
dotnet ./bin/client.dll <config_file.xml> 
```



## Step 2: Using multi-dimensional scaling to generate reference centers

go to the root folder of TVMC, `cd ./TVMC`, and run

```
python .\get_reference_center.py --dataset basketball_player --num_frames 10 --num_centers 1995 --centers_dir ..\arap-volume-tracking\data\basketball-output-max-2000/impr
```

The `--num_centers` is set to 1995 because global optimization mode changes . You can set how many centers you want to remove before running the global optimization mode. Please set the right center number.

Now `reference_centers_aligned.xyz` is generated in `./arap-volume-tracking/data/basketball-output-max-2000/impr/reference`

(When the number of volume center exceeds a certain value, MDS may give abnormal output, you may need to try different `random_state` for a optimal result.)

## Step 3: Get transformation dual quaternions 

`cd ./TVMC`

```
python .\get_transformation.py --dataset basketball_player --num_frames 10 --num_centers 1995 --centers_dir ..\arap-volume-tracking\data\basketball-output-max-2000\impr --firstIndex 11 --lastIndex 20 
```



## Step 4: Create volume-tracked self-contact-free reference mesh

So far, we've got a set of reference centers, let's deform meshes to the reference shape.

go to `cd ./tvm-editing`, then build

```
dotnet build  TVMEditor.sln --configuration Release --no-incremental
```

> Usage: Program <dataset> <mode> <firstIndex> <lastIndex> [inputDir] [outputDir]
> <dataset>: dancer | basketball | mitch | thomas
> <mode>: 1 (deform mesh to the reference shape) | 2 (deform reference mesh back to each mesh in the group)
> <firstIndex>: Starting index of the files to process
> <lastIndex>: Ending index of the files to process
> [inputDir]: Optional, default is 'Data/basketball_player_2000'
> [outputDir]: Optional, default is 'output'

```
TVMEditor.Test\bin\Release\net5.0\TVMEditor.Test.exe basketball 1 11 20 ".\TVMEditor.Test\bin\Release\net5.0\Data\basketball_player_1995/" ".\TVMEditor.Test\bin\Release\net5.0\output\basketball_player_1995\" 
```



Then go to `cd ./TVMC`, run

```
python .\extract_reference_mesh.py --dataset basketball_player --num_frames 10 --num_centers 1995 --inputDir ..\tvm-editing\TVMEditor.Test\bin\Release\net5.0\output\basketball_player_1995\output\ --outputDir ..\tvm-editing\TVMEditor.Test\bin\Release\net5.0\Data\basketball_player_1995\reference_mesh\ --firstIndex 11 --lastIndex 20
```



## Step 5: Deform reference mesh to each mesh in the group

Recall that the key idea is the deform the self-contact-free reference mesh to get approximation of each meshes in the group, so that we can compress a group of meshes with one reference mesh and some displacement fields, which saves bitrates. 

To deform the self-contact-free reference mesh "back", run `tvm-editing` again. 

 `cd ./tvm-editing`, then execute 

```
TVMEditor.Test\bin\Release\net5.0\TVMEditor.Test.exe basketball 2 11 20 ".\TVMEditor.Test\bin\Release\net5.0\Data\basketball_player_1995" ".\TVMEditor.Test\bin\Release\net5.0\output\basketball_player_1995\" 
```



## Step 6: Get displacement fields					

The most significant difference between time-varying mesh sequences and dynamic mesh sequences is **varying topology**, which means although adjacent meshes in the sequence has similar shapes, they have different number of vertices and connectivity. Thanks to TVMC, these deformed reference meshes are "tracked" with the self-contact-free reference mesh.

```
python .\get_displacements.py --dataset basketball_player --num_frames 10 --num_centers 1995 --target_mesh_path ..\arap-volume-tracking\data\basketball --firstIndex 11 --lastIndex 20
```

Now, we've got everything for compression. You can use anything you want to compress the decimated reference mesh and these displacements. 

In TVMC, we store displacements as `.ply` files and use Google Draco to compress both the reference mesh and displacements, I'm pretty sure that there are other ways that can get even better compression performance (e.g., video coding for displacements, because there are some redundancy between displacements, the movement of a person or object has a certain "inertia"). 



## *Step 7: Compression and evaluation 

```
git clone git@github.com:google/draco.git
```

```
mkdir build && cd build
```

```
cmake ../ -G "Visual Studio 17 2022" -A Win32
```

To generate 64-bit Windows Visual Studio 2022 projects:

```
cmake ../ -G "Visual Studio 17 2022" -A x64
```

Then

```
cmake --build . --config Release
```

Draco encoder path: `./draco/build/Release/draco.encoder.exe`

Draco decoder path: `./draco/build/Release/draco.decoder.exe`

```
python .\evaluation.py --dataset basketball_player --num_frames 10 --num_centers 1995 --firstIndex 11 --lastIndex 20 --fileNamePrefix basketball_player_fr0 --encoderPath ..\draco\build_dir\Release\draco_encoder.exe --decoderPath ..\draco\build_dir\Release\draco_decoder.exe --qp 10
```

