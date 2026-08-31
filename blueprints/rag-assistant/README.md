# Onflow Developer Assistant

Blueprint này triển khai cổng tài liệu và trợ lý AI hỗ trợ tích hợp Onflow Open API trên DigitalOcean.

Sau khi triển khai, ứng dụng cung cấp:

- Trợ lý RAG trả lời bằng tiếng Việt dựa trên tài liệu Onflow.
- Tài liệu **API Tiêu chuẩn** tại `/api-docs/`.
- Tài liệu **API Doanh nghiệp** tại `/enterprise-docs/`.
- Knowledge Base được khởi tạo từ `https://developers.onflow.vn/api-docs/`.
- Guardrail tùy chọn cho jailbreak, kiểm duyệt nội dung và dữ liệu nhạy cảm.
- Tích hợp Taiga tùy chọn để tra cứu và tạo issue.

## Kiến trúc

```text
Người dùng
    │
    ▼
developers.onflow.vn
    │
    ├── /                    → React UI → FastAPI → DigitalOcean GenAI Agent
    ├── /api-docs/           → Apidog project 565199
    └── /enterprise-docs/    → Apidog project 763179
                                             │
GenAI Agent ← Guardrails                     │
    │                                        │
    ▼                                        │
Knowledge Base ← Onflow API documentation ───┘
```

Các thành phần chính:

| Thành phần | Vai trò |
|---|---|
| DigitalOcean App Platform | Chạy Nginx, FastAPI và giao diện React |
| DigitalOcean GenAI Agent | Sinh câu trả lời và cung cấp trích dẫn |
| DigitalOcean Knowledge Base | Lập chỉ mục tài liệu Onflow để truy xuất ngữ cảnh |
| Nginx | Phân tuyến Developer Portal và hai bộ tài liệu Apidog |
| OpenSearch | Database được gắn với ứng dụng App Platform |

## Luồng xử lý câu hỏi

1. Người dùng gửi câu hỏi từ giao diện React.
2. FastAPI chuyển nội dung và lịch sử hội thoại đến GenAI Agent qua streaming API.
3. Agent truy xuất các đoạn liên quan trong Knowledge Base.
4. Guardrail kiểm tra yêu cầu và phản hồi nếu đã được cấu hình.
5. Câu trả lời được stream về trình duyệt.

Ứng dụng không lưu lịch sử hội thoại ở server. Lịch sử gần nhất được giữ trong trình duyệt của người dùng.

## Yêu cầu

- Terraform tương thích với DigitalOcean provider `~> 2.81.0`.
- DigitalOcean API token có quyền tạo và cập nhật tài nguyên.
- UUID của embedding model.
- UUID của inference model nếu tạo agent mới.
- Quyền quản lý domain `developers.onflow.vn` trên DigitalOcean App Platform.
- Cluster OpenSearch production có tên `genai-seahorse` trong tài khoản DigitalOcean. Blueprint hiện chỉ gắn cluster này vào App Platform, không tự tạo cluster.
- Node.js 20 và Python 3.12 nếu chạy local.

## Triển khai bằng Terraform

### 1. Tạo cấu hình

Tạo file `terraform.tfvars` trong `blueprints/rag-assistant/`:

```hcl
do_token            = "dop_v1_your_token"
model_uuid           = "your-inference-model-uuid"
embedding_model_uuid = "your-embedding-model-uuid"

basename     = "onflow-developer-assistant"
project_name = "Onflow Developer Assistant"
region       = "sgp1"

# Repo/branch App Platform sẽ dùng để build chat UI.
_app_source_repo   = "your-github-org/your-repository"
_app_source_branch = "master"
```

Không commit `terraform.tfvars` hoặc API token vào Git.

App Platform build trực tiếp từ `_app_source_repo` và `_app_source_branch`, không build từ checkout local đang chạy Terraform. Giá trị mặc định hiện là `digitalocean/marketplace-blueprints` và `master`; hãy đổi hai biến này khi triển khai từ fork hoặc branch khác.

### 2. Kiểm tra và triển khai

```bash
cd blueprints/rag-assistant
terraform init
terraform validate
terraform plan
terraform apply
```

Terraform kiểm tra trạng thái indexing mỗi 10 giây trong tối đa khoảng 10 phút, sau đó thử gắn Knowledge Base vào agent. Nếu indexing chưa hoàn tất hoặc bước gắn thất bại, kiểm tra log của `null_resource.agent_post_setup` và trạng thái Knowledge Base trên DigitalOcean.

### 3. Xem kết quả

```bash
terraform output app_url
terraform output agent_uuid
terraform output knowledge_base_uuid
```

Các URL production chính:

| Chức năng | URL |
|---|---|
| Trợ lý API | `https://developers.onflow.vn/` |
| API Tiêu chuẩn | `https://developers.onflow.vn/api-docs/` |
| API Doanh nghiệp | `https://developers.onflow.vn/enterprise-docs/` |
| Health check | `https://developers.onflow.vn/health` |

## Dùng agent có sẵn

Để sử dụng một GenAI Agent hiện có thay vì tạo agent mới:

```hcl
existing_agent_uuid  = "your-agent-uuid"
existing_agent_name  = "Onflow API Assistant"
embedding_model_uuid = "your-embedding-model-uuid"
```

Blueprint vẫn tạo Knowledge Base và gắn Knowledge Base này vào agent đã chọn. `DO_API_TOKEN` phải có quyền đọc agent, tạo API key và quản lý Knowledge Base.

## Các biến Terraform

### Bắt buộc và tài nguyên chính

| Biến | Mặc định | Mô tả |
|---|---:|---|
| `do_token` | Bắt buộc | DigitalOcean API token; được đánh dấu sensitive |
| `embedding_model_uuid` | Bắt buộc | UUID của embedding model cho Knowledge Base |
| `model_uuid` | `""` | UUID inference model; bắt buộc khi tạo agent mới |
| `existing_agent_uuid` | `""` | UUID agent có sẵn; để trống để Terraform tạo agent mới |
| `existing_agent_name` | `RAG Assistant` | Tên hiển thị của agent có sẵn |
| `project_uuid` | `""` | Project hiện có; để trống để tạo project mới |
| `basename` | `rag-assistant` | Tiền tố tên tài nguyên |
| `project_name` | `""` | Tên project; mặc định dùng `basename` |
| `region` | `nyc3` | Region của App Platform |
| `app_instance_size` | `apps-s-1vcpu-1gb` | Kích thước instance App Platform |
| `_app_source_repo` | `digitalocean/marketplace-blueprints` | GitHub repository App Platform dùng để build |
| `_app_source_branch` | `master` | Git branch App Platform dùng để build |

### Cấu hình agent

| Biến | Mặc định | Mô tả |
|---|---:|---|
| `default_model` | `nvidia-nemotron-3-super-120b` | Tên model dùng để hiển thị/tham chiếu |
| `embedding_model` | `qwen3-embedding-0.6b` | Tên embedding model dùng để hiển thị/tham chiếu |
| `agent_instruction` | Xem `variables.tf` | System instruction của trợ lý |
| `agent_temperature` | `0` | Độ ngẫu nhiên của phản hồi |
| `agent_max_tokens` | `4096` | Số token tối đa của phản hồi |
| `agent_k` | `15` | Số tài liệu được truy xuất cho mỗi câu hỏi |
| `agent_retrieval_method` | `RETRIEVAL_METHOD_SUB_QUERIES` | Phương thức truy xuất Knowledge Base |

### Guardrail tùy chọn

| Biến | Mặc định | Mô tả |
|---|---:|---|
| `guardrail_jailbreak_uuid` | `""` | UUID guardrail phát hiện jailbreak |
| `guardrail_content_mod_uuid` | `""` | UUID guardrail kiểm duyệt nội dung |
| `guardrail_sensitive_data_uuid` | `""` | UUID guardrail phát hiện dữ liệu nhạy cảm |

Để trống UUID nếu không sử dụng guardrail tương ứng.

### Taiga tùy chọn

| Biến | Mặc định | Mô tả |
|---|---:|---|
| `taiga_base_url` | `""` | API base URL, ví dụ `https://api.taiga.io/api/v1` |
| `taiga_username` | `""` | Tên đăng nhập Taiga |
| `taiga_password` | `""` | Mật khẩu Taiga; được đánh dấu sensitive |
| `taiga_auth_token` | `""` | Token dùng thay username/password |
| `taiga_project_id` | `""` | ID project cần tra cứu |
| `taiga_project_slug` | `""` | Slug dùng khi không cấu hình project ID |

Taiga chỉ sử dụng được khi có `taiga_base_url`, thông tin xác thực và một trong hai giá trị `taiga_project_id` hoặc `taiga_project_slug`.

## Terraform outputs

| Output | Mô tả |
|---|---|
| `app_url` | URL ứng dụng App Platform |
| `agent_uuid` | UUID của agent đang được sử dụng |
| `knowledge_base_uuid` | UUID Knowledge Base |
| `project_id` | DigitalOcean Project ID |
| `app_platform_id` | App Platform resource ID |
| `agent_id` | GenAI Agent resource ID |
| `knowledge_base_id` | Knowledge Base resource ID |

## Chạy local

Chat UI gồm React/Vite ở frontend và FastAPI ở backend. Backend cần kết nối đến một GenAI Agent đã được deploy.

### Chạy backend

```bash
cd blueprints/rag-assistant/chat-ui
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export AGENT_UUID="your-agent-uuid"
export DO_API_TOKEN="dop_v1_your_token"
export AGENT_NAME="Onflow API Assistant"

uvicorn main:app --host 0.0.0.0 --port 8080
```

Backend tự lấy deployment URL của agent và tạo một agent API key khi khởi động. Kiểm tra trạng thái bằng:

```bash
curl http://localhost:8080/health
```

### Chạy frontend với hot reload

Mở terminal thứ hai:

```bash
cd blueprints/rag-assistant/chat-ui
npm ci
npm run dev
```

Vite sẽ proxy `/api` và `/health` sang FastAPI tại port `8080`.

### Build frontend production

```bash
npm run build
```

File build được tạo trong `chat-ui/static/` và được FastAPI phục vụ tại `/static/`.

Lưu ý: proxy Apidog trong `nginx.conf` chỉ hoạt động khi chạy container hoặc Nginx; Vite dev server không phục vụ `/api-docs/` và `/enterprise-docs/`.

## Cấu trúc thư mục

```text
rag-assistant/
├── agent.tf                 # Agent và bước gắn KB/guardrail
├── app.tf                   # App Platform, domain và environment variables
├── knowledge_base.tf        # Knowledge Base và nguồn crawler
├── outputs.tf               # Terraform outputs
├── projects.tf              # DigitalOcean Project
├── provider.tf              # Provider DigitalOcean
├── variables.tf             # Cấu hình blueprint
└── chat-ui/
    ├── chat_app/            # FastAPI routes và tích hợp dịch vụ
    ├── frontend/            # React source
    ├── static/              # Frontend production build
    ├── nginx.conf           # Proxy portal và Apidog
    ├── Dockerfile           # Multi-stage image
    └── start-chat-ui.sh     # Chạy Uvicorn và Nginx
```

## Backend API

Các endpoint dưới đây hiện đi qua route public của App Platform và **chưa có lớp xác thực riêng**. Đặc biệt, các thao tác tạo Taiga issue, upload tài liệu và xóa Knowledge Base data source sử dụng quyền của service token ở backend. Không mở các endpoint quản trị này cho người dùng không tin cậy; cần bổ sung authentication/authorization hoặc chặn ở gateway trước khi dùng trong production.

| Method | Endpoint | Mô tả |
|---|---|---|
| `GET` | `/health` | Trạng thái ứng dụng và agent |
| `POST` | `/api/chat` | Chat không streaming |
| `POST` | `/api/chat/stream` | Chat streaming |
| `GET` | `/api/knowledge-bases` | Danh sách Knowledge Base |
| `POST` | `/api/knowledge-bases/uploads/file` | Upload tài liệu vào Knowledge Base |
| `DELETE` | `/api/knowledge-bases/{kb}/data-sources/{source}` | Xóa data source khỏi Knowledge Base |
| `GET` | `/api/taiga/search` | Tìm kiếm dữ liệu Taiga |
| `GET` | `/api/taiga/metadata` | Metadata project Taiga |
| `POST` | `/api/taiga/issues` | Tạo Taiga issue |

## Vận hành và xử lý lỗi

- **Ứng dụng không khởi động:** xem App Platform/Uvicorn logs trước; agent discovery chạy lúc startup và sẽ dừng ứng dụng nếu `AGENT_UUID`, `DO_API_TOKEN`, deployment URL hoặc bước tạo agent API key không hợp lệ.
- **Knowledge Base chưa trả kết quả:** đợi indexing hoàn tất và kiểm tra Knowledge Base đã được gắn vào agent.
- **Tài liệu Apidog lỗi:** kiểm tra project ID và các route trong `chat-ui/nginx.conf`.
- **Domain chưa hoạt động:** kiểm tra domain mapping và DNS của `developers.onflow.vn` trong App Platform.
- **Taiga trả về 503:** bổ sung base URL, thông tin xác thực và project ID/slug.
- **Upload thất bại:** kích thước mặc định tối đa là 25 MB; định dạng mặc định gồm PDF, TXT, Markdown, HTML, CSV và DOCX.

## Bảo mật

- Không đưa `do_token`, `DO_API_TOKEN`, mật khẩu Taiga hoặc agent API key vào Git và log.
- Bảo vệ Terraform state vì state có thể chứa dữ liệu nhạy cảm; với môi trường dùng chung, nên dùng remote backend được mã hóa và kiểm soát truy cập.
- App Platform lưu DigitalOcean token và thông tin xác thực Taiga dưới dạng secret.
- Agent API key được tạo khi ứng dụng khởi động và chỉ giữ trong bộ nhớ tiến trình.
- Các endpoint quản trị Knowledge Base và Taiga hiện chưa xác thực; phải giới hạn truy cập trước khi vận hành production.
- Nên kiểm thử tích hợp Onflow trên Staging trước Production.
- Guardrail là lớp bảo vệ bổ sung, không thay thế việc phân quyền, quản lý secret và xác thực input.
