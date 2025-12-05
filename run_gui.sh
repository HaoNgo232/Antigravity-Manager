#!/bin/bash
cd "$(dirname "$0")"

# ============================================================================
# Hàm kiểm tra và fix libmpv trên Linux
# ============================================================================
fix_libmpv_linux() {
    # Chỉ chạy trên Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        return 0
    fi
    
    echo "Kiểm tra thư viện libmpv..."
    
    # Kiểm tra libmpv.so.1 có tồn tại không
    if ldconfig -p 2>/dev/null | grep -q "libmpv.so.1"; then
        echo "libmpv.so.1 đã có sẵn"
        return 0
    fi
    
    echo "Không tìm thấy libmpv.so.1 (Flet yêu cầu)"
    
    # Kiểm tra libmpv.so.2 có tồn tại không
    if ! ldconfig -p 2>/dev/null | grep -q "libmpv.so.2"; then
        echo "Đang cài đặt libmpv2..."
        
        # Phát hiện package manager và cài đặt
        if command -v apt &> /dev/null; then
            echo "   Sử dụng apt (Debian/Ubuntu/Mint)..."
            sudo apt update && sudo apt install -y libmpv2
        elif command -v dnf &> /dev/null; then
            echo "   Sử dụng dnf (Fedora)..."
            sudo dnf install -y mpv-libs
        elif command -v yum &> /dev/null; then
            echo "   Sử dụng yum (RHEL/CentOS)..."
            sudo yum install -y mpv-libs
        else
            echo "Không thể tự động cài đặt libmpv2."
            echo "   Vui lòng cài đặt thủ công:"
            echo "   - Debian/Ubuntu/Mint: sudo apt install libmpv2"
            echo "   - Fedora: sudo dnf install mpv-libs"
            echo "   - RHEL/CentOS: sudo yum install mpv-libs"
            return 1
        fi
        
        # Kiểm tra lại sau khi cài
        if ! ldconfig -p 2>/dev/null | grep -q "libmpv.so.2"; then
            echo "Cài đặt libmpv2 thất bại."
            return 1
        fi
    else
        echo "Đã tìm thấy libmpv.so.2"
    fi
    
    # Tìm đường dẫn chính xác của libmpv.so.2
    LIBMPV2_PATH=$(ldconfig -p 2>/dev/null | grep "libmpv.so.2" | awk '{print $NF}' | head -n1)
    
    if [ -z "$LIBMPV2_PATH" ]; then
        echo "Không thể xác định đường dẫn libmpv.so.2"
        return 1
    fi
    
    # Tạo đường dẫn cho symlink (thay .so.2 thành .so.1)
    SYMLINK_PATH="${LIBMPV2_PATH%.2}.1"
    
    # Kiểm tra xem symlink đã tồn tại và trỏ đúng chưa
    if [ -L "$SYMLINK_PATH" ]; then
        # Symlink đã tồn tại, kiểm tra xem nó có trỏ đúng không
        CURRENT_TARGET=$(readlink -f "$SYMLINK_PATH")
        EXPECTED_TARGET=$(readlink -f "$LIBMPV2_PATH")
        
        if [ "$CURRENT_TARGET" = "$EXPECTED_TARGET" ]; then
            echo "Symbolic link đã tồn tại và trỏ đúng"
            return 0
        else
            echo "Symbolic link tồn tại nhưng trỏ sai, đang cập nhật..."
        fi
    fi
    
    # Tạo hoặc cập nhật symlink (cần sudo)
    echo "🔗 Tạo symbolic link:"
    echo "   $SYMLINK_PATH -> $LIBMPV2_PATH"
    
    sudo ln -sf "$LIBMPV2_PATH" "$SYMLINK_PATH"
    
    if [ $? -eq 0 ]; then
        # Cập nhật ldconfig cache
        sudo ldconfig 2>/dev/null
        echo "Đã tạo symbolic link thành công!"
        return 0
    else
        echo "Không thể tạo symbolic link. Vui lòng chạy với quyền sudo."
        return 1
    fi
}

# ============================================================================
# Fix libmpv trước khi chạy ứng dụng
# ============================================================================
fix_libmpv_linux

# ============================================================================
# Thiết lập Python Virtual Environment
# ============================================================================
if [ ! -d ".venv" ]; then
    echo "Tạo virtual environment..."
    python3 -m venv .venv
    source .venv/bin/activate
    echo "Cài đặt dependencies..."
    pip install -r requirements.txt
else
    source .venv/bin/activate
fi

# ============================================================================
# Chạy ứng dụng GUI
# ============================================================================
echo "Khởi động Antigravity Manager..."
python3 gui/main.py
