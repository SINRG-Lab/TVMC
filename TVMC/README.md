# **TVMC: Time-Varying Mesh Compression Using Volume-Tracked Reference Meshes**

Guodong Chen, Filip Hácha, Libor Váša, Mallesham Dasari

![alt text](https://github.com/frozzzen3/TVMC/blob/main/images/TVMC-workflow.png?raw=true)

This repository contains the official authors implementation associated with the paper **"TVMC: Time-Varying Mesh Compression Using Volume-Tracked Reference Meshes"**, which can be found [here] (to be added), accepted by [2025 ACM MMSys](https://2025.acmmmsys.org/).

## Step-by-step Tutorial

I'll use `basketball player ` dataset from [TDMD](https://multimedia.tencent.com/resources/tdmd) to show the whole pipeline.

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



Some other time-varying mesh sequences are stored in `./arap-volume-tracking/data`.

Configuration files can be found in `./arap-volume-tracking/config`

You may be curious about why there are three folders, actually `./iir` `./impr` `./max` represent different configuration files for three tracking modes, please find more details and examples [here](https://github.com/frozzzen3/TVMC/blob/main/arap-volume-tracking/README.md).

To run ARAP volume tracking on your own dataset,  create configuration file then execute

```
dotnet ./bin/client.dll <config_file.xml> 
```



Global optimization mode is optional, it can only be adopted after getting volume centers, it will try to remove a certain number of abnormal volume centers and adjust positions of the remains.

## Step 2: Using multi-dimensional scaling to generate reference centers

go to the root folder of TVMC, `cd ./TVMC`, and run

```
python .\get_reference_center.py --dataset basketball_player --num_frames 10 --num_centers 2000 --centers_dir ..\arap-volume-tracking\data\basketball-output-max-2000
```

Now `reference_centers_aligned.xyz` is generated in `./arap-volume-tracking/data/basketball-output-max-2000`

(When the number of volume center exceeds a certain value, MDS may give abnormal output, you may need to try different `random_state` for a better result.)

## Step 3: Get transformation dual quaternions 

`cd ./TVMC`

```
python .\get_transformation.py --dataset basketball_player --num_frames 10 --num_centers 2000 --centers_dir ..\arap-volume-tracking\data\basketball-output-max-2000\ --firstIndex 10 --lastIndex 25
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
TVMEditor.Test\bin\Release\net5.0\TVMEditor.Test.exe basketball 1 10 19 ".\TVMEditor.Test\bin\Release\net5.0\Data\basketball_player_2000" ".\TVMEditor.Test\bin\Release\net5.0\output\basketball_player_2000\"
```



Then go to `cd ./TVMC`, run

```
python .\extract_reference_mesh.py --dataset basketball_player --num_frames 10 --num_centers 2000 --inputDir ..\tvm-editing\TVMEditor.Test\bin\Release\net5.0\output\basketball_player_2000\output\ --outputDir ..\tvm-editing\TVMEditor.Test\bin\Release\net5.0\Data\basketball_player_2000\reference_mesh\ --firstIndex 10 --lastIndex 19
```

