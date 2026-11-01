#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <oleidl.h>
#include <string>
#include <vector>

class FileDropTarget;

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  void OnTrayCommand(UINT command) override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void QueueDroppedFiles(std::vector<std::string> paths);
  void FlushPendingDroppedFiles();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> tray_channel_;
  std::vector<std::string> pending_dropped_files_;
  bool dart_ready_for_drops_ = false;
  bool drop_delivery_in_flight_ = false;
  FileDropTarget* file_drop_target_ = nullptr;
  bool drop_target_registered_on_window_ = false;
  bool drop_target_registered_on_view_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
