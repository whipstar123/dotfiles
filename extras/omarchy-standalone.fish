# Omarchy Standalone session environment (Fish).
# Installed to ~/.config/fish/conf.d/omarchy-standalone.fish.
set -gx OMARCHY_PATH /usr/share/omarchy-standalone
fish_add_path $OMARCHY_PATH/bin
set -gx EDITOR "omarchy-launch-editor --inline"
