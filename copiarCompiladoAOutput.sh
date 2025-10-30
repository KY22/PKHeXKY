!#/bin/bash

# 1. Build the image
echo "Build the image"
docker build -t pkhex-builder .

# 2. Create volume and copy built app
echo "Create volume and copy built app"
docker volume create pkhex-volume
docker run --rm -v pkhex-volume:/pkhex-output pkhex-builder

# 3. Extract to host
echo "Extract to host"
mkdir -p ./PKHeXKY-build
chmod -R lan:lan ./PKHeXKY-build
docker run --rm -v pkhex-volume:/source -v $(pwd)/PKHeXKY-build://home/lan/Git/PKHeXKY alpine cp -r /source/. /home/lan/Git/PKHeXKY/

# 4. Verify the extracted files
echo "Verify extracted files"
ls -la ./PKHeXKY-build/

# 5. Clean up (optional)
echo "Clean up, delete volume"
docker volume rm pkhex-volume
