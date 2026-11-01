#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <ole2.h>
#include <shellapi.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr wchar_t kSingleInstanceMutexName[] =
    L"Local\\EFOMA.Bifrost.SingleInstance";
constexpr wchar_t kLegacyWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

bool HasCommandLineArgument(const wchar_t* expected) {
  int count = 0;
  LPWSTR* arguments = CommandLineToArgvW(GetCommandLineW(), &count);
  if (!arguments) return false;
  bool found = false;
  for (int index = 1; index < count; ++index) {
    if (std::wstring(arguments[index]) == expected) {
      found = true;
      break;
    }
  }
  LocalFree(arguments);
  return found;
}

int ShutdownExistingInstanceForInstaller() {
  HWND window = FindWindowW(kBifrostWindowClassName, L"Bifrost");
  if (!window) window = FindWindowW(kLegacyWindowClassName, L"Bifrost");
  if (!window) return 0;
  if (!PostMessageW(window, WM_APP + 2, 0, 0)) return 2;
  for (int attempt = 0; attempt < 150; ++attempt) {
    if (!IsWindow(window)) return 1;
    Sleep(100);
  }
  return 2;
}

HWND FindExistingBifrostWindow() {
  for (int attempt = 0; attempt < 50; ++attempt) {
    HWND window = FindWindowW(kBifrostWindowClassName, L"Bifrost");
    if (window) return window;
    Sleep(100);
  }
  return nullptr;
}

void ForwardFileArguments(HWND window,
                          const std::vector<std::string>& arguments) {
  std::string payload;
  for (const auto& argument : arguments) {
    if (argument.empty() || argument.rfind("--", 0) == 0) continue;
    payload.append(argument);
    payload.push_back('\0');
  }
  if (payload.empty()) return;
  payload.push_back('\0');

  COPYDATASTRUCT data{};
  data.dwData = kBifrostForwardFilesData;
  data.cbData = static_cast<DWORD>(payload.size());
  data.lpData = payload.data();
  DWORD_PTR result = 0;
  SendMessageTimeoutW(window, WM_COPYDATA, 0,
                      reinterpret_cast<LPARAM>(&data), SMTO_ABORTIFHUNG,
                      3000, &result);
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  if (HasCommandLineArgument(L"--installer-shutdown")) {
    return ShutdownExistingInstanceForInstaller();
  }

  HANDLE single_instance_mutex = CreateMutexW(
      nullptr, TRUE, kSingleInstanceMutexName);
  if (!single_instance_mutex) return EXIT_FAILURE;
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    const auto arguments = GetCommandLineArguments();
    HWND existing_window = FindExistingBifrostWindow();
    if (existing_window) {
      ForwardFileArguments(existing_window, arguments);
      if (!HasCommandLineArgument(L"--minimized-to-tray")) {
        DWORD existing_process_id = 0;
        GetWindowThreadProcessId(existing_window, &existing_process_id);
        if (existing_process_id != 0) {
          AllowSetForegroundWindow(existing_process_id);
        }
        PostMessageW(existing_window, kBifrostActivateExistingMessage, 0, 0);
      }
    }
    CloseHandle(single_instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize OLE for native Windows drag-and-drop and COM-based plugins.
  ::OleInitialize(nullptr);

  flutter::DartProject project(L"data");
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Bifrost", origin, size)) {
    ::OleUninitialize();
    ReleaseMutex(single_instance_mutex);
    CloseHandle(single_instance_mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::OleUninitialize();
  ReleaseMutex(single_instance_mutex);
  CloseHandle(single_instance_mutex);
  return EXIT_SUCCESS;
}
