# Kiểm chứng logic menu/touch trên iOS Simulator

App gốc là arm64 **device** (không có slice simulator) nên không chạy được trực tiếp.
Bộ này thay thế bằng cách: build **chính diag.m đang ship** cho simulator, nhúng vào
một app harness có hierarchy giống game (UIWindow + rootVC + gameView), kèm các class
giả của LOL.framework (`MenuLoad`, `ImGuiDrawView`, `OBF_SK92E1B48`).

Harness đo bằng **UIKit thật**:
1. menu đóng → `[window hitTest:]` phải trả về game view (chạm tới game).
2. mở menu (`showChange:YES`) → view menu phải được gắn vào hierarchy.
3. đóng menu (`showChange:NO`) → `[window hitTest:]` phải trả về game view lại.

Kết quả ghi vào `Documents/harness.log` và được workflow in ra.

## Chạy trên GitHub Actions (macos-14 có sẵn Xcode + Simulator)
Đưa thư mục `sim/` và `.github/` vào repo của bạn rồi push, hoặc chạy workflow
`ios-touch-test` bằng tay (tab Actions → Run workflow).

## Chạy trên Mac có Xcode
```
cd sim && ./build_and_test.sh
```
