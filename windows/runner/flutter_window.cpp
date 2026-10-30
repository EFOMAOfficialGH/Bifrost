#include "flutter_window.h"

#include <optional>
#include <shellapi.h>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {
bool ShouldStartMinimizedToTray() {
  int argument_count = 0;
  LPWSTR* arguments = CommandLineToArgvW(GetCommandLineW(), &argument_count);
  if (!arguments) return false;
  bool minimized = false;
  for (int index = 1; index < argument_count; ++index) {
    if (std::wstring(arguments[index]) == L"--minimized-to-tray") {
      minimized = true;
      break;
    }
  }
  LocalFree(arguments);
  return minimized;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  tray_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "bifrost/tray",
      &flutter::StandardMethodCodec::GetInstance());
  tray_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "showUpdateBalloon") {
          result->NotImplemented();
          return;
        }
        NOTIFYICONDATA data{};
        data.cbSize = sizeof(data);
        data.hWnd = GetHandle();
        data.uID = 1;
        data.uFlags = NIF_INFO;
        wcscpy_s(data.szInfoTitle, _countof(data.szInfoTitle), L"Bifrost update");
        wcscpy_s(data.szInfo, _countof(data.szInfo),
                 L"Update available. Open Bifrost to review it.");
        data.dwInfoFlags = NIIF_INFO;
        data.uTimeout = 10000;
        if (Shell_NotifyIcon(NIM_MODIFY, &data)) {
          result->Success();
        } else {
          result->Error("TRAY_UNAVAILABLE", "The Bifrost tray icon is unavailable.", nullptr);
        }
      });
  AddTrayIcon();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (!ShouldStartMinimizedToTray()) this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  tray_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::OnTrayCommand(UINT command) {
  if (!tray_channel_) return;
  if (command == 1) {
    tray_channel_->InvokeMethod("sendFiles", nullptr);
  } else if (command == 2) {
    tray_channel_->InvokeMethod("checkForUpdates", nullptr);
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE) {
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
