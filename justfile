set dotenv-load := true

mod_directory := "NewRatkin-Pretty-Glasses"

# This texture-only mod has no source code to format.
fmt:
    true

# Validate the runtime mod files.
build:
    #!/bin/sh
    set -eu
    python3 -c 'import xml.etree.ElementTree as ET; ET.parse("About/About.xml"); ET.parse("LoadFolders.xml")'
    expected='RK_ResearchGlasses_Fat_east.png RK_ResearchGlasses_Fat_south.png RK_ResearchGlasses_Thin_east.png RK_ResearchGlasses_Thin_north.png RK_ResearchGlasses_Thin_south.png RK_ResearchGlasses_east.png RK_ResearchGlasses_north.png RK_ResearchGlasses_south.png'
    for name in $expected; do
        path="1.6/Textures/Apparel/$name"
        test -f "$path"
        file "$path" | grep -q 'PNG image data'
    done
    test "$(find 1.6/Textures/Apparel -type f | wc -l)" -eq 8

# Validate and install the complete runtime mod locally.
install: build
    #!/bin/sh
    set -eu
    mods_directory="${RIMWORLD_DIR}/Mods"
    if [ ! -d "$mods_directory" ]; then
        printf 'RimWorld Mods directory not found: %s\n' "$mods_directory" >&2
        exit 1
    fi
    destination="$mods_directory/{{ mod_directory }}"
    mkdir -p "$destination"
    rsync --archive --delete --delete-excluded \
        --exclude '/.*' \
        --exclude '/README*' \
        --exclude '/justfile' \
        ./ "$destination/"
    printf 'Installed {{ mod_directory }} to %s\n' "$destination"

# Validate, install, and enable the mod locally.
install-enable: install
    #!/usr/bin/env python3
    import os
    import subprocess
    import xml.etree.ElementTree as ET
    from pathlib import Path

    if subprocess.run(
        ["pgrep", "-x", "RimWorldLinux"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0:
        raise SystemExit("Close RimWorld before enabling the mod.")

    package_id = (ET.parse("About/About.xml").getroot().findtext("packageId") or "").strip()
    if not package_id:
        raise SystemExit("About/About.xml has no packageId.")

    config_path = Path(os.environ["RIMWORLD_MODS_CONFIG"])
    tree = ET.parse(config_path)
    active_mods = tree.getroot().find("activeMods")
    if active_mods is None:
        raise SystemExit(f"{config_path} has no activeMods element.")

    if package_id in ((node.text or "").strip() for node in active_mods.findall("li")):
        print(f"{package_id} is already enabled.")
        raise SystemExit(0)

    ET.SubElement(active_mods, "li").text = package_id
    ET.indent(tree, space="  ")
    temporary_path = config_path.with_name(f"{config_path.name}.tmp")
    tree.write(temporary_path, encoding="utf-8", xml_declaration=True)
    os.chmod(temporary_path, config_path.stat().st_mode)
    temporary_path.replace(config_path)
    print(f"Enabled {package_id} in {config_path}.")
