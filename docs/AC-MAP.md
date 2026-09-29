# Bản đồ kiểm tra bot SCP

Cập nhật 28/09/2026. Nguồn yêu cầu: `SPEC.md`.
“Có ca đạt” chỉ áp dụng những tình huống thực sự được viết; không đồng nghĩa toàn bộ yêu cầu đã nghiệm thu.

| Yêu cầu | Nơi xử lý | Bằng chứng và giới hạn |
|---|---|---|
| AC01–AC04: bật vùng, hai chiều, không vào mù | ScpEpisodes, ScpScenario | AC01/02, AC-E1..5, REG01/02/06; đã có ca đi qua cập nhật nến trước xét phản ứng |
| AC05–AC09: phá/kiểm tra lại/phá giả | ScpEpisodes, ScpScenario | AC05/06/09, REG10; cần mở rộng tình huống hủy và nhiều lần đổi vai trò |
| AC10: tránh đuổi giá | ScpPlan, GateSendable | AC10, REG08/09; khóa giá/thời điểm xác nhận |
| AC11: hồi nông | ScpScenario | AC11a/b; chưa chứng minh hiệu quả trên giá mới |
| AC12: đi ngang | ScpScenario | AC12; quy tắc chọn giữa nhiều cụm còn cần rà đầy đủ |
| AC13–AC16: EMA và mẫu thay thế | ScpReaction, ScpScenario | AC13/14/15/16, REG05; EMA nguồn M5 được xác nhận M1 |
| AC17–AC18: trùng/xung đột | ScpScenario, ScpExec | Có mã dấu xác nhận và khóa gửi; chưa phủ đủ mọi vùng chồng/đa terminal |
| AC19–AC20: vùng lớn và vùng yếu | ScpZones | REG03/13/14; hai chạm không đủ nâng mức vùng |
| AC21–AC23: thời điểm biết dữ liệu | ScpSeries, ScpFeed | AC21, REG12; nhận bù hủy theo dõi, còn cần thử mất mạng thật |
| AC24–AC25: tính tiền/khối lượng | ScpPlan | AC25, ví dụ V08, kiểm ký quỹ/chi phí; cần thêm loại tài khoản và phí khác |
| AC26: bảo vệ sau khớp | ScpExec | ScpExecVerify kiểm có SL/TP và sửa sai bị từ chối; chưa phủ mọi kiểu khớp một phần |
| AC27: kết quả gửi chưa rõ | ScpExec | ScpExecVerify: SENT_UNKNOWN không tự hết hạn; không mô phỏng mọi lỗi mạng sàn |
| AC28: thứ tự dữ liệu | ScpFeed, ScpSeries | AC28 kiểm nến trùng/ngược; chưa phải ca bao phủ toàn bộ tick trùng mili giây |
| AC29: chạm dừng rồi đi đúng | Nghiên cứu kết quả | Chưa có đối chứng đủ để kết luận chất lượng dừng |
| AC30–AC33: quản lý sau khớp | ScpManage | PX01–PX19: bảo vệ giá vào, chốt phần, không đóng theo phút, hồi nhẹ không đủ thoát; ScpExecVerify và ScpPriceManageVerify kiểm khớp/chống lặp/TP giữ nguyên |
| AC34: không vào lại bằng xác nhận cũ | ScpScenario, ScpEpisodes | AC34, REG05/08; mốc đóng lệnh và lần rời vùng được kiểm |
| AC35: khôi phục | ScpExec, ScpState | ScpExecVerify kiểm khởi tạo lại đối tượng; không thay thế thử mất điện thật |
| AC36: giới hạn lỗ | ScpSafety, ScpState | ScpExecVerify kiểm giữ khóa sau cập nhật/khởi tạo lại; thêm ca biên nạp/rút/đổi tuần còn cần |
| AC37: lịch tin | ScpSafety | Có chặn thiếu lịch ngoài máy thử; lịch đầy đủ và múi giờ cần nghiệm thu trước demo |
| AC38: quyền từng nhánh | BotScpMtf | Input gửi riêng, mặc định tắt; chưa có nhánh được cho phép vận hành |
| AC39: cùng một giây | ScpFeed | Đọc MqlTick/time_msc, không bỏ theo một giây; chưa có bộ tick sàn kiểm đầy đủ |
| AC40: đo độ trễ | BotScpMtf | Có p50/p95/p99 cửa sổ 4096 mẫu; chưa đo độ trễ sàn thật |
| AC41: chạy lâu/tính nối tiếp | ScpSeries | REG04 5000 nến; REG15/16 4000 nến so công thức độc lập |

## Công cụ

- `ScpVerify.mq5`: ca tính toán và chuỗi trạng thái.
- `ScpExecVerify.mq5`: EA chỉ cho máy thử, kiểm thực thi bằng giao dịch trong Strategy Tester.
- Không sử dụng số ca tổng để suy ra tỷ lệ bao phủ SPEC. Chi tiết kết quả tại
  `reports/scp-review-fixes-20260928.md`.
