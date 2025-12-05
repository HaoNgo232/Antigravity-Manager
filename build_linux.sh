#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting Antigravity Manager build for Linux..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error counter
WARNINGS=0

# Helper function for warnings
warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

# Helper function for errors
error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Helper function for success
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Helper function for info
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 1. Check dependencies
echo "🔍 Checking dependencies..."

# Check if Python 3.10+ is available
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
    error "Python 3.10+ is required. Current version: $PYTHON_VERSION"
fi

success "Python $PYTHON_VERSION detected"

# Check for wget
if ! command -v wget &> /dev/null; then
    warn "wget not found. Installing..."
    sudo apt-get update && sudo apt-get install -y wget || error "Failed to install wget"
fi

# Check for ImageMagick (optional but recommended)
if ! command -v convert &> /dev/null; then
    warn "ImageMagick not found. Icon conversion will be limited."
    info "Install with: sudo apt install imagemagick"
else
    success "ImageMagick detected"
fi

# Check for FUSE (optional but recommended)
if ! command -v fusermount &> /dev/null && [ ! -f /usr/bin/fusermount ]; then
    warn "FUSE not found. AppImage may require --appimage-extract-and-run flag"
    info "Install with: sudo apt install fuse libfuse2"
else
    success "FUSE detected"
fi

# 2. Validate project structure
echo "🔍 Validating project structure..."

# Check if required directories exist
if [ ! -d "gui" ]; then
    error "gui directory not found. Are you in the project root?"
fi

if [ ! -d "assets" ]; then
    error "assets directory not found"
fi

if [ ! -f "gui/main.py" ]; then
    error "gui/main.py not found"
fi

success "Project structure validated"

# 3. Auto-fix common issues
echo "🔧 Checking and fixing common issues..."

# Fix 1: Ensure views/__init__.py exists
if [ ! -f "gui/views/__init__.py" ]; then
    warn "gui/views/__init__.py missing. Creating..."
    cat > "gui/views/__init__.py" << 'PYEOF'
# Views package
from .home_view import HomeView
from .settings_view import SettingsView

__all__ = ['HomeView', 'SettingsView']
PYEOF
    success "Created gui/views/__init__.py"
else
    success "gui/views/__init__.py exists"
fi

# Fix 2: Ensure gui/__init__.py exists
if [ ! -f "gui/__init__.py" ]; then
    info "Creating gui/__init__.py for proper package structure"
    touch "gui/__init__.py"
fi

# 4. Check virtual environment
if [ ! -d ".venv" ]; then
    warn "Virtual environment not found. Creating..."
    python3 -m venv .venv || error "Failed to create virtual environment"
    success "Virtual environment created"
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source .venv/bin/activate

# 5. Install/upgrade required packages
echo "📦 Installing Python dependencies..."
pip install --upgrade pip -q
pip install -r requirements.txt -q
pip install pyinstaller -q

success "Dependencies installed"

# 6. Sync assets
echo "📦 Syncing assets..."
mkdir -p gui/assets
cp -R assets/* gui/assets/
cp requirements.txt gui/requirements.txt

success "Assets synced"

# 7. Clean old builds
echo "🧹 Cleaning old build files..."
rm -rf gui/build gui/dist
rm -rf build dist
rm -rf *.AppImage
rm -rf AppDir

success "Old builds cleaned"

# 8. Build with PyInstaller
echo "🔨 Building executable with PyInstaller..."
cd gui

# Validate that all imports work before building
info "Pre-build validation..."
python3 -c "
import sys
sys.path.insert(0, '.')
try:
    from views import HomeView, SettingsView
    import account_manager
    import db_manager
    import process_manager
    import utils
    import theme
    import icons
    print('✅ All imports validated')
except ImportError as e:
    print(f'❌ Import error: {e}')
    sys.exit(1)
" || error "Pre-build validation failed"

pyinstaller --clean --noconfirm \
    --name "Antigravity Manager" \
    --onedir \
    --windowed \
    --paths "." \
    --add-data "assets:assets" \
    --collect-submodules "views" \
    --hidden-import "account_manager" \
    --hidden-import "db_manager" \
    --hidden-import "process_manager" \
    --hidden-import "utils" \
    --hidden-import "theme" \
    --hidden-import "icons" \
    main.py 2>&1 | grep -E "(INFO|ERROR|WARNING)" | tail -20

cd ..

# Check if build succeeded
if [ ! -d "gui/dist/Antigravity Manager" ]; then
    error "PyInstaller build failed - executable directory not found"
fi

if [ ! -f "gui/dist/Antigravity Manager/Antigravity Manager" ]; then
    error "PyInstaller build failed - executable file not found"
fi

success "PyInstaller build successful"

# 9. Create AppImage structure
echo "📦 Creating AppImage structure..."

APP_DIR="AppDir"
mkdir -p "$APP_DIR/usr/bin"
mkdir -p "$APP_DIR/usr/share/applications"
mkdir -p "$APP_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$APP_DIR/usr/share/metainfo"

# Copy the built application
echo "📋 Copying application files..."
cp -r "gui/dist/Antigravity Manager"/* "$APP_DIR/usr/bin/"

# Verify executable was copied
if [ ! -f "$APP_DIR/usr/bin/Antigravity Manager" ]; then
    error "Failed to copy executable to AppDir"
fi

success "Application files copied"

# Create desktop entry in the ROOT of AppDir (required by appimagetool)
echo "📝 Creating desktop entry..."
cat > "$APP_DIR/antigravity-manager.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Antigravity Manager
Comment=Modern Multi-Account Management Tool for Antigravity
Exec=Antigravity Manager
Icon=antigravity-manager
Categories=Utility;
Terminal=false
EOF

# Also create a copy in the standard location for proper integration
cp "$APP_DIR/antigravity-manager.desktop" "$APP_DIR/usr/share/applications/antigravity-manager.desktop"

success "Desktop entry created"

# Copy icon (convert from ico to png if needed)
if command -v convert &> /dev/null; then
    echo "🎨 Converting icon..."
    if convert "assets/icon.ico[0]" -resize 256x256 "$APP_DIR/usr/share/icons/hicolor/256x256/apps/antigravity-manager.png" 2>/dev/null; then
        success "Icon converted to PNG"
    else
        warn "Icon conversion failed, using .ico directly"
        cp "assets/icon.ico" "$APP_DIR/antigravity-manager.png"
    fi
else
    warn "ImageMagick not found, using .ico directly"
    cp "assets/icon.ico" "$APP_DIR/antigravity-manager.png"
fi

# Create AppRun script
echo "📝 Creating AppRun script..."
cat > "$APP_DIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin/:${HERE}/usr/sbin/:${HERE}/usr/games/:${HERE}/bin/:${HERE}/sbin/${PATH:+:$PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib/:${HERE}/usr/lib/i386-linux-gnu/:${HERE}/usr/lib/x86_64-linux-gnu/:${HERE}/usr/lib32/:${HERE}/usr/lib64/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="${HERE}/usr/bin/:${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONHOME="${HERE}/usr"
export XDG_DATA_DIRS="${HERE}/usr/share/${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
# Extract full Exec value including spaces
EXEC=$(grep -e '^Exec=.*' "${HERE}"/*.desktop | head -n 1 | cut -d "=" -f 2-)
exec "${HERE}/usr/bin/${EXEC}" "$@"
EOF

chmod +x "$APP_DIR/AppRun"

# Verify AppRun is executable
if [ ! -x "$APP_DIR/AppRun" ]; then
    error "AppRun script is not executable"
fi

success "AppRun script created"

# Create AppStream metadata
cat > "$APP_DIR/usr/share/metainfo/antigravity-manager.appdata.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>com.ctrler.antigravity.manager</id>
  <metadata_license>MIT</metadata_license>
  <project_license>MIT</project_license>
  <name>Antigravity Manager</name>
  <summary>Modern Multi-Account Management Tool for Antigravity</summary>
  <description>
    <p>
      Antigravity Manager is a powerful utility designed to solve the pain point 
      of Antigravity client's lack of native multi-account switching support.
    </p>
  </description>
  <launchable type="desktop-id">antigravity-manager.desktop</launchable>
  <provides>
    <binary>Antigravity Manager</binary>
  </provides>
  <releases>
    <release version="1.0.0" date="2025-12-05"/>
  </releases>
</component>
EOF

# 10. Download and use appimagetool
echo "📥 Downloading appimagetool..."
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    wget -q --show-progress "$APPIMAGETOOL_URL" -O appimagetool-x86_64.AppImage || error "Failed to download appimagetool"
    chmod +x appimagetool-x86_64.AppImage
    success "appimagetool downloaded"
else
    info "Using existing appimagetool"
fi

# Verify appimagetool is executable
if [ ! -x "appimagetool-x86_64.AppImage" ]; then
    error "appimagetool is not executable"
fi

# 11. Create AppImage
echo "🔧 Creating AppImage..."
# Use --no-appstream to skip validation warnings
if ARCH=x86_64 ./appimagetool-x86_64.AppImage --no-appstream "$APP_DIR" "Antigravity-Manager-x86_64.AppImage" 2>&1 | grep -v "^$"; then
    success "AppImage created"
else
    error "Failed to create AppImage"
fi

# 12. Verify AppImage
if [ ! -f "Antigravity-Manager-x86_64.AppImage" ]; then
    error "AppImage file not found after build"
fi

# Make AppImage executable
chmod +x "Antigravity-Manager-x86_64.AppImage"

# Verify it's executable
if [ ! -x "Antigravity-Manager-x86_64.AppImage" ]; then
    error "AppImage is not executable"
fi

success "AppImage is executable"

# 13. Cleanup
echo "🧹 Cleaning up temporary files..."
rm -rf "$APP_DIR"
rm -rf gui/build gui/dist
rm -rf build dist

success "Cleanup complete"

# 14. Final validation
echo "🔍 Running final validation..."

# Check file size (should be reasonable, not too small or too large)
APPIMAGE_SIZE=$(stat -f%z "Antigravity-Manager-x86_64.AppImage" 2>/dev/null || stat -c%s "Antigravity-Manager-x86_64.AppImage")
APPIMAGE_SIZE_MB=$((APPIMAGE_SIZE / 1024 / 1024))

if [ "$APPIMAGE_SIZE_MB" -lt 5 ]; then
    warn "AppImage size is suspiciously small (${APPIMAGE_SIZE_MB}MB). Build may be incomplete."
elif [ "$APPIMAGE_SIZE_MB" -gt 100 ]; then
    warn "AppImage size is large (${APPIMAGE_SIZE_MB}MB). Consider optimization."
else
    success "AppImage size: ${APPIMAGE_SIZE_MB}MB"
fi

# Verify it's actually an ELF executable
if file "Antigravity-Manager-x86_64.AppImage" | grep -q "ELF.*executable"; then
    success "AppImage is a valid ELF executable"
else
    error "AppImage is not a valid executable"
fi

# 15. Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "🎉 Build completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 AppImage location: $(pwd)/Antigravity-Manager-x86_64.AppImage"
echo "📊 Size: ${APPIMAGE_SIZE_MB}MB"
echo "🔐 MD5: $(md5sum Antigravity-Manager-x86_64.AppImage | cut -d' ' -f1)"
echo ""
echo "To run the application:"
echo "  ${GREEN}./Antigravity-Manager-x86_64.AppImage${NC}"
echo ""
echo "To install (optional):"
echo "  ${BLUE}mv Antigravity-Manager-x86_64.AppImage ~/.local/bin/${NC}"
echo "  or"
echo "  ${BLUE}sudo mv Antigravity-Manager-x86_64.AppImage /usr/local/bin/${NC}"
echo ""

if [ "$WARNINGS" -gt 0 ]; then
    warn "Build completed with $WARNINGS warning(s). Check output above."
else
    success "Build completed with no warnings!"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

