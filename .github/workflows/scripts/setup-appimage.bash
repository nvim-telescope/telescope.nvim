#!/bin/bash
# Script that will be run both from ci.yml and docgen.yml
# when downloading the appimage.
mkdir -p build
wget https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
chmod +x nvim.appimage
mv nvim.appimage ./build
# AppImages require FUSE to run: https://docs.appimage.org/user-guide/troubleshooting/fuse.html#setting-up-fuse-on-ubuntu-debian-and-their-derivatives            # NOTE: afaik contaniers can't modprobe
# and afaik docker containers can't run kernel mdoules.
# XXX: Should we create a script somewhere... instead of this hacky workaround??
echo "
#!/bin/bash
./build/nvim.appimage --appimage-extract-and-run \"\$@\"
" > ./build/nvim
chmod +x ./build/nvim
