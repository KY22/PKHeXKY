!#/bin/bash

# 1. Build the image
echo "Build the image"
podman build -t pkhex-builder .

# 2. Create volume and copy built app
echo "Create volume and copy built app"
podman volume create pkhex-volume
podman run --rm -v pkhex-volume:/pkhex-output pkhex-builder

# 3. Extract to host
echo "Extract to host"
mkdir -p ./Build
chown -R lan:lan ./Build
podman run --rm -v pkhex-volume:/source -v $(pwd)/Build://home/lan/Git/PKHeXKY alpine cp -r /source/. /home/lan/Git/PKHeXKY/

# 4. Verify the extracted files
echo "Verify extracted files"
ls -la ./Build/

# 5. Clean up (optional)
echo "Clean up, delete volume"
podman volume rm pkhex-volume
