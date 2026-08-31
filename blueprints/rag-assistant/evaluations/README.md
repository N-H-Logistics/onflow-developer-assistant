# Onflow Agent Evaluation Dataset

Thư mục này chứa bộ dữ liệu baseline để đánh giá Onflow Developer Assistant bằng DigitalOcean Agent Evaluations.

## Dataset

`onflow-agent-baseline.csv` gồm 50 test case với hai cột:

| Cột | Ý nghĩa |
|---|---|
| `query` | Câu hỏi được gửi đến agent |
| `expected_response` | Nội dung chuẩn dùng cho Ground Truth Faithfulness |

Các nhóm kiểm thử gồm:

- Môi trường và xác thực.
- Order, shipment, pickup address và inventory product.
- Webhook và idempotency.
- Retry và xử lý lỗi.
- Bảo vệ secret và prompt injection.
- Câu hỏi ngoài phạm vi, thiếu dữ liệu hoặc không có trong tài liệu.

## Chạy trên DigitalOcean

1. Mở **Inference → Agent Platform → Workspace → Evaluations**.
2. Chọn **Create test case**.
3. Chọn các nhóm mục tiêu đánh giá, sau đó tùy chỉnh các metric phù hợp:
   - Correctness.
   - Context Adherence.
   - Retrieved Context Relevance.
   - Response-Context Completeness.
   - Instruction Following.
   - PII Leaks và Prompt Injection.
4. Chọn `Ground Truth Faithfulness` làm star metric và đặt pass threshold.
5. Upload `onflow-agent-baseline.csv` làm dataset.
6. Chọn Onflow agent và version cần đánh giá, sau đó chạy evaluation.
7. Lưu kết quả làm baseline trước khi thay đổi model, instruction, Knowledge Base hoặc retrieval settings.

Evaluation sử dụng token có tính phí. Dữ liệu input/output có thể được gửi đến judge model bên thứ ba theo chính sách của DigitalOcean; không thêm API key, PII hoặc dữ liệu khách hàng vào dataset.

## Tiêu chí phát hành đề xuất

- Không có lỗi tiết lộ secret hoặc endpoint tự bịa.
- Endpoint và HTTP method cốt lõi phải đúng 100%.
- Ground Truth Faithfulness đạt ngưỡng đã thống nhất, đề xuất bắt đầu từ 0.9.
- Các test case Correctness hoặc Context Adherence dưới ngưỡng phải được review thủ công.
- Chạy lại cùng dataset sau mỗi thay đổi đáng kể để so sánh với baseline.

## Bảo trì

- Cập nhật đáp án khi tài liệu Onflow thay đổi.
- Thêm câu hỏi production đã được ẩn danh nếu phát hiện failure mode mới.
- Không sửa dataset trong khi một evaluation run đang chạy.
- Giữ nguyên một phiên bản baseline cố định để so sánh giữa các lần chạy.
