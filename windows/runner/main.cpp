#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shellapi.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {
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
  HWND window = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Bifrost");
  if (!window) return 0;
  if (!PostMessageW(window, WM_APP + 2, 0, 0)) return 2;
  for (int attempt = 0; attempt < 150; ++attempt) {
    if (!IsWindow(window)) return 1;
    Sleep(100);
  }
  return 2;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (HasCommandLineArgument(L"--installer-shutdown")) {
    return ShutdownExistingInstanceForInstaller();
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Bifrost", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
