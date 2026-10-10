# Requires a POSIX-compatible shell on Windows (e.g. Git Bash / sh.exe).
# Linux/macOS users can use their default shell.

# --- Project Configuration ---
project := "74hc165-module"
kicad_version := "10.0"

# --- Derived Variables ---
board := project + ".kicad_pcb"
sch_file := project + ".kicad_sch"
render_opts := "--background transparent --quality basic --rotate -45,0,45 --width 1024 --height 1024 --zoom 0.75"

# Dynamically resolve OS-specific commands
kikit_cmd := if os() == "windows" { "'C:/Program Files/KiCad/" + kicad_version + "/bin/python.exe' -m kikit.ui" } else { "python3 -m kikit.ui" }
ibom_cmd := if os() == "windows" { "'C:/Program Files/KiCad/" + kicad_version + "/bin/python.exe' '" + env_var("USERPROFILE") + "/Documents/KiCad/" + kicad_version + "/3rdparty/plugins/org_openscopeproject_InteractiveHtmlBom/generate_interactive_bom.py'" } else { "generate_interactive_bom" }

# Show available commands by default
default:
    @just --list

# Generate all release artifacts
all: fab schematic step render bom

# Generate ALL fabrication files (Single Board + Panel)
fab: fab-board fab-panel

# Export ONLY single board fabrication files
fab-board:
    @echo "Exporting single board Gerbers..."
    mkdir -p fab/board
    kicad-cli pcb export gerbers -o fab/board/ --board-plot-params {{ board }}
    kicad-cli pcb export drill -o fab/board/ --excellon-separate-th {{ board }}

# Generate ONLY the panelized .kicad_pcb file (Prerequisite)
panel-pcb:
    @echo "Generating panelized board..."
    mkdir -p panel
    {{ kikit_cmd }} panelize -p panel/kikit-config.json {{ board }} panel/{{ project }}-panel.kicad_pcb

# Export ONLY panel fabrication files
fab-panel: panel-pcb
    @echo "Exporting panel Gerbers..."
    mkdir -p fab/panel
    kicad-cli pcb export gerbers -o fab/panel/ --no-protel-ext --layers F.Cu,B.Cu,F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts,User.Comments panel/{{ project }}-panel.kicad_pcb
    kicad-cli pcb export drill -o fab/panel/ --excellon-separate-th panel/{{ project }}-panel.kicad_pcb

# Generate ALL Bill of Materials (CSV + Interactive HTML)
bom: bom-csv ibom

# Export standard CSV BOM for PCBA manufacturing
bom-csv:
    @echo "Exporting standard CSV BOM..."
    mkdir -p bom
    kicad-cli sch export bom -o bom/{{ project }}-bom.csv --preset "Simple BOM" {{ sch_file }}

# Export Interactive HTML BOM for manual assembly
ibom:
    @echo "Exporting Interactive HTML BOM..."
    mkdir -p bom
    {{ ibom_cmd }} --no-browser --use-ini {{ board }}

# Export schematic PDF
schematic:
    @echo "Exporting schematic PDF..."
    mkdir -p docs
    kicad-cli sch export pdf -o docs/{{ project }}-schematic.pdf --theme "KiCad Default" --no-background-color {{ sch_file }}

# Export 3D STEP model
step:
    @echo "Exporting STEP model..."
    mkdir -p cad
    kicad-cli pcb export step -o cad/{{ project }}.step --subst-models -f {{ board }}

# NOTE: kicad-cli render inherits your global KiCad 3D viewer settings (colors, visibility, etc.).
# The repository images were generated using KiCad's default 3D viewer configuration.
# (Depends on panel-pcb to ensure the panel board exists before rendering)

# Render 3D images
render: panel-pcb
    @echo "Rendering 3D images..."
    mkdir -p assets/images

    @echo "Rendering single board..."
    kicad-cli pcb render -o assets/images/board-front.png --side top {{ render_opts }} {{ board }}
    kicad-cli pcb render -o assets/images/board-back.png --side bottom {{ render_opts }} {{ board }}

    @echo "Rendering panelized board..."
    kicad-cli pcb render -o assets/images/panel-front.png --side top {{ render_opts }} panel/{{ project }}-panel.kicad_pcb
    kicad-cli pcb render -o assets/images/panel-back.png --side bottom {{ render_opts }} panel/{{ project }}-panel.kicad_pcb

# Clean all generated files (preserves tracked assets)
clean:
    @echo "Cleaning build artifacts..."
    rm -rf fab/ cad/ bom/
    rm -f docs/{{ project }}-schematic.pdf
    rm -rf panel/{{ project }}-panel.* panel/~{{ project }}-panel.* panel/.history/
