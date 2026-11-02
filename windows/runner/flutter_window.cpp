#include "flutter_window.h"

#include <algorithm>
#include <optional>
#include <functional>
#include <iterator>
#include <commctrl.h>
#include <shellapi.h>
#include <string>
#include <utility>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {
class DropDeliveryResult final
    : public flutter::MethodResult<flutter::EncodableValue> {
 public:
  explicit DropDeliveryResult(std::function<void(bool)> on_complete)
      : on_complete_(std::move(on_complete)) {}

 protected:
  void SuccessInternal(const flutter::EncodableValue*) override {
    on_complete_(true);
  }
  void ErrorInternal(const std::string&, const std::string&,
                     const flutter::EncodableValue*) override {
    on_complete_(false);
  }
  void NotImplementedInternal() override { on_complete_(false); }

 private:
  std::function<void(bool)> on_complete_;
};

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

LRESULT CALLBACK ForwardChildFileDrop(HWND window, UINT message,
                                      WPARAM wparam, LPARAM lparam,
                                      UINT_PTR subclass_id,
                                      DWORD_PTR reference_data) {
  if (message == WM_DROPFILES) {
    const HWND owner = reinterpret_cast<HWND>(reference_data);
    if (owner && PostMessageW(owner, WM_DROPFILES, wparam, 0)) return 0;
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

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
  HWND flutter_view = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(flutter_view);
  DragAcceptFiles(GetHandle(), TRUE);
  DragAcceptFiles(flutter_view, TRUE);
  if (!SetWindowSubclass(flutter_view, ForwardChildFileDrop, 0,
                         reinterpret_cast<DWORD_PTR>(GetHandle()))) {
    DragAcceptFiles(flutter_view, FALSE);
  }
  tray_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "bifrost/tray",
      &flutter::StandardMethodCodec::GetInstance());
  tray_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "readyForFileDrop") {
          dart_ready_for_drops_ = true;
          FlushPendingDroppedFiles();
          result->Success();
          return;
        }
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
  if (flutter_controller_ && flutter_controller_->view()) {
    HWND flutter_view = flutter_controller_->view()->GetNativeWindow();
    if (flutter_view) {
      RemoveWindowSubclass(flutter_view, ForwardChildFileDrop, 0);
      DragAcceptFiles(flutter_view, FALSE);
    }
  }
  DragAcceptFiles(GetHandle(), FALSE);
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

void FlutterWindow::QueueDroppedFiles(std::vector<std::string> paths) {
  pending_dropped_files_.insert(pending_dropped_files_.end(),
                                std::make_move_iterator(paths.begin()),
                                std::make_move_iterator(paths.end()));
  FlushPendingDroppedFiles();
}

void FlutterWindow::FlushPendingDroppedFiles() {
  if (!dart_ready_for_drops_ || !tray_channel_ ||
      pending_dropped_files_.empty() || drop_delivery_in_flight_) {
    return;
  }
  flutter::EncodableList paths;
  paths.reserve(pending_dropped_files_.size());
  for (const auto& path : pending_dropped_files_) {
    paths.emplace_back(path);
  }
  const size_t delivered_count = pending_dropped_files_.size();
  drop_delivery_in_flight_ = true;
  tray_channel_->InvokeMethod(
      "droppedFiles",
      std::make_unique<flutter::EncodableValue>(std::move(paths)),
      std::make_unique<DropDeliveryResult>([this, delivered_count](bool accepted) {
        drop_delivery_in_flight_ = false;
        if (accepted) {
          const size_t acknowledged =
              std::min(delivered_count, pending_dropped_files_.size());
          pending_dropped_files_.erase(pending_dropped_files_.begin(),
                                       pending_dropped_files_.begin() + acknowledged);
        }
        if (accepted) FlushPendingDroppedFiles();
      }));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kBifrostActivateExistingMessage) {
    ShowWindow(hwnd, IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
    BringWindowToTop(hwnd);
    SetForegroundWindow(hwnd);
    return 0;
  }
  if (message == WM_DROPFILES) {
    HDROP dropped_files = reinterpret_cast<HDROP>(wparam);
    const UINT count = DragQueryFileW(dropped_files, 0xFFFFFFFF, nullptr, 0);
    std::vector<std::string> paths;
    paths.reserve(count);
    for (UINT index = 0; index < count; ++index) {
      const UINT length = DragQueryFileW(dropped_files, index, nullptr, 0);
      std::wstring path(length + 1, L'\0');
      const UINT copied =
          DragQueryFileW(dropped_files, index, path.data(), length + 1);
      path.resize(copied);
      auto utf8_path = Utf8FromUtf16(path.c_str());
      if (!utf8_path.empty()) paths.push_back(std::move(utf8_path));
    }
    DragFinish(dropped_files);
    QueueDroppedFiles(std::move(paths));
    return 0;
  }
  if (message == WM_COPYDATA) {
    const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
    if (!data || data->dwData != kBifrostForwardFilesData || !data->lpData ||
        data->cbData == 0 || data->cbData > 1024 * 1024) {
      return FALSE;
    }
    const std::string payload(static_cast<const char*>(data->lpData),
                              data->cbData);
    std::vector<std::string> paths;
    size_t start = 0;
    while (start < payload.size()) {
      const size_t end = payload.find('\0', start);
      if (end == std::string::npos) break;
      if (end > start) paths.push_back(payload.substr(start, end - start));
      start = end + 1;
    }
    QueueDroppedFiles(std::move(paths));
    return TRUE;
  }
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
