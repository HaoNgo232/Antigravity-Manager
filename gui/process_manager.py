# -*- coding: utf-8 -*-
import os
import time
import platform
import subprocess
import psutil

# Use relative imports
from utils import info, error, warning, get_antigravity_executable_path, open_uri

def is_process_running(process_name=None):
    """检查 Antigravity 进程是否在运行
    
    使用跨平台的检测方式：
    - macOS: 检查路径包含 Antigravity.app
    - Windows: 检查进程名或路径包含 antigravity
    - Linux: 检查进程名或路径包含 antigravity
    """
    system = platform.system()
    
    for proc in psutil.process_iter(['name', 'exe']):
        try:
            process_name_lower = proc.info['name'].lower() if proc.info['name'] else ""
            exe_path = proc.info.get('exe', '').lower() if proc.info.get('exe') else ""
            
            # 跨平台检测
            is_antigravity = False
            
            if system == "Darwin":
                # macOS: 检查路径包含 Antigravity.app
                is_antigravity = 'antigravity.app' in exe_path
            elif system == "Windows":
                # Windows: 检查进程名或路径包含 antigravity
                is_antigravity = (process_name_lower in ['antigravity.exe', 'antigravity'] or 
                                 'antigravity' in exe_path)
            else:
                # Linux: 检查进程名或路径包含 antigravity
                # Tên chính xác hoặc đường dẫn chứa antigravity (tránh false positive)
                is_antigravity = (
                    process_name_lower == 'antigravity' or 
                    '/antigravity/' in exe_path or 
                    exe_path.endswith('/antigravity')
                )
            
            if is_antigravity:
                return True
                
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    return False

def close_antigravity(timeout=10, force_kill=True):
    """优雅地关闭所有 Antigravity 进程
    
    关闭策略（三阶段，跨平台）：
    1. 平台特定的优雅退出方式
       - macOS: AppleScript
       - Windows: taskkill /IM (优雅终止)
       - Linux: SIGTERM
    2. 温和终止 (SIGTERM/TerminateProcess) - 给进程机会清理
    3. 强制杀死 (SIGKILL/taskkill /F) - 最后手段
    """
    info("Trying to close Antigravity...")
    system = platform.system()
    
    # Platform check
    if system not in ["Darwin", "Windows", "Linux"]:
        warning(f"Unknown system platform: {system}，将尝试通用方法")
    
    try:
        # 阶段 1: 平台特定的优雅退出
        if system == "Darwin":
            # macOS: 使用 AppleScript
            info("Trying to gracefully exit Antigravity via AppleScript...")
            try:
                result = subprocess.run(
                    ["osascript", "-e", 'tell application "Antigravity" to quit'],
                    capture_output=True,
                    timeout=3
                )
                if result.returncode == 0:
                    info("Exit request sent, waiting for application response...")
                    time.sleep(2)
            except Exception as e:
                warning(f"AppleScript exit failed: {e}，将使用其他方式")
        
        elif system == "Windows":
            # Windows: 使用 taskkill 优雅终止（不带 /F 参数）
            info("Trying to gracefully exit Antigravity via taskkill...")
            try:
                # CREATE_NO_WINDOW = 0x08000000
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                
                result = subprocess.run(
                    ["taskkill", "/IM", "Antigravity.exe", "/T"],
                    capture_output=True,
                    timeout=3,
                    creationflags=0x08000000
                )
                if result.returncode == 0:
                    info("Exit request sent, waiting for application response...")
                    time.sleep(2)
            except Exception as e:
                warning(f"taskkill exit failed: {e}，将使用其他方式")
        
        # Linux 不需要特殊处理，直接使用 SIGTERM
        
        # 检查并收集仍在运行的进程
        target_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'exe']):
            try:
                process_name_lower = proc.info['name'].lower() if proc.info['name'] else ""
                exe_path = proc.info.get('exe', '').lower() if proc.info.get('exe') else ""
                
                # 排除自身进程
                if proc.pid == os.getpid():
                    continue
                
                # 排除当前应用目录下的所有进程 (防止误杀自己和子进程)
                # 在 PyInstaller 打包环境中，sys.executable 指向 exe 文件
                # 在开发环境中，它指向 python.exe
                try:
                    import sys
                    current_exe = sys.executable
                    current_dir = os.path.dirname(os.path.abspath(current_exe)).lower()
                    if exe_path and current_dir in exe_path:
                        # print(f"DEBUG: Skipping process in current dir: {proc.info['name']}")
                        continue
                except:
                    pass

                # 跨平台检测：检查进程名或可执行文件路径
                is_antigravity = False
                
                if system == "Darwin":
                    # macOS: 检查路径包含 Antigravity.app
                    is_antigravity = 'antigravity.app' in exe_path
                elif system == "Windows":
                    # Windows: 严格匹配进程名 antigravity.exe
                    # 或者路径包含 antigravity 且进程名不是 Antigravity Manager.exe
                    is_target_name = process_name_lower in ['antigravity.exe', 'antigravity']
                    is_in_path = 'antigravity' in exe_path
                    is_manager = 'manager' in process_name_lower
                    
                    is_antigravity = is_target_name or (is_in_path and not is_manager)
                else:
                    # Linux: 检查进程名或路径包含 antigravity
                    # Tên chính xác hoặc đường dẫn chứa antigravity (tránh false positive)
                    is_antigravity = (
                        process_name_lower == 'antigravity' or 
                        '/antigravity/' in exe_path or 
                        exe_path.endswith('/antigravity')
                    )
                
                if is_antigravity:
                    info(f"Found target process: {proc.info['name']} ({proc.pid}) - {exe_path}")
                    target_processes.append(proc)
                    
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue

        if not target_processes:
            info("All Antigravity processes closed normally")
            return True
        
        info(f"Detected {len(target_processes)} 个进程仍在运行")

        # 阶段 2: 温和地请求进程终止 (SIGTERM)
        info("Sending termination signal (SIGTERM)...")
        for proc in target_processes:
            try:
                if proc.is_running():
                    proc.terminate()
            except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
                continue
            except Exception as e:
                continue

        # 等待进程自然终止
        info(f"Waiting for process exit (max {timeout} 秒）...")
        start_time = time.time()
        while time.time() - start_time < timeout:
            still_running = []
            for proc in target_processes:
                try:
                    if proc.is_running():
                        still_running.append(proc)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
            if not still_running:
                info("All Antigravity processes closed normally")
                return True
                
            time.sleep(0.5)

        # 阶段 3: 强制终止顽固进程 (SIGKILL)
        if still_running:
            still_running_names = ", ".join([f"{p.info['name']}({p.pid})" for p in still_running])
            warning(f"Still {len(still_running)} 个进程未退出: {still_running_names}")
            
            if force_kill:
                info("Sending forced termination signal (SIGKILL)...")
                for proc in still_running:
                    try:
                        if proc.is_running():
                            proc.kill()
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        continue
                
                # 最后检查
                time.sleep(1)
                final_check = []
                for proc in still_running:
                    try:
                        if proc.is_running():
                            final_check.append(proc)
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        continue
                
                if not final_check:
                    info("All Antigravity processes terminated")
                    return True
                else:
                    final_list = ", ".join([f"{p.info['name']}({p.pid})" for p in final_check])
                    error(f"Processes that cannot be terminated: {final_list}")
                    return False
            else:
                error("Some processes failed to close, please close manually and retry")
                return False
                
        return True

    except Exception as e:
        error(f"Error occurred while closing Antigravity process: {str(e)}")
        return False

def start_antigravity(use_uri=True):
    """启动 Antigravity
    
    Args:
        use_uri: 是否使用 URI 协议启动（默认 True）
                 URI 协议更可靠，不需要查找可执行文件路径
    """
    info("Starting Antigravity...")
    system = platform.system()
    
    try:
        # 优先使用 URI 协议启动（跨平台通用）
        if use_uri:
            info("Starting using URI protocol...")
            uri = "antigravity://oauth-success"
            
            if open_uri(uri):
                info("Antigravity URI start command sent")
                return True
            else:
                warning("URI start failed, trying executable path...")
                # 继续执行下面的备用方案
        
        # 备用方案：使用可执行文件路径启动
        info("Starting using executable path...")
        if system == "Darwin":
            subprocess.Popen(["open", "-a", "Antigravity"])
        elif system == "Windows":
            path = get_antigravity_executable_path()
            if path and path.exists():
                # CREATE_NO_WINDOW = 0x08000000
                subprocess.Popen([str(path)], creationflags=0x08000000)
            else:
                error("Cannot find Antigravity executable")
                warning("Tip: Can try starting with URI protocol (use_uri=True)")
                return False
        elif system == "Linux":
            # Tìm đường dẫn Antigravity executable
            path = get_antigravity_executable_path()
            if path and path.exists():
                subprocess.Popen([str(path)])
            else:
                # Fallback: thử gọi trực tiếp (nếu có trong PATH)
                try:
                    subprocess.Popen(["antigravity"])
                except FileNotFoundError:
                    error("Không tìm thấy Antigravity executable")
                    error("Vui lòng đảm bảo Antigravity đã được cài đặt")
                    return False
        
        info("Antigravity start command sent")
        return True
    except Exception as e:
        error(f"Error starting process: {e}")
        # 如果 URI 启动失败，尝试使用可执行文件路径
        if use_uri:
            warning("URI start failed, trying executable path...")
            return start_antigravity(use_uri=False)
        return False
