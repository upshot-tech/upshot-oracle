#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0

# if any command fails then immediately exit
set -o errexit

echo ""
echo "Building in order to generate ABIs..."
forge build
echo "Build complete."

declare -a fileList
fileList+=( "contracts/IUpshotOracle.sol" "contracts/UpshotOracle.sol" )

declare -a outPathList

for file in "${fileList[@]}";
do
    if [[ $file =~ .*.sol ]]; then
        IFS="\/" read -a filePathArray <<< "$file"
        filePathArrayLen=${#filePathArray[@]}
        fileP=${filePathArray[$filePathArrayLen-1]}
        jsonP=$(echo "$fileP" | sed 's#.sol#.json#')
        outP="./out/$fileP/$jsonP"
        if [[ -f $outP ]]; then
            outPathList+=( $outP )
        else
            echo "could not find file compilation! $fileP"
            exit 1;
        fi
    fi
done

echo ""
echo "Generating typechain artifacts from ABIs..."
rm -rf types
for file in "${outPathList[@]}";
do
    echo "generating typechain for $file"
    yarn typechain --target ethers-v5 --out-dir types $file
done
echo 'Typechain generation complete. Find them in ./types/'
