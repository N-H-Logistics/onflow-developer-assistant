FROM node:20-slim AS frontend

WORKDIR /build

COPY package.json package-lock.json ./
RUN npm ci

COPY frontend ./frontend
COPY vite.config.js .
RUN npm run build

FROM python:3.12-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates nginx \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
COPY --from=frontend /build/static ./static
COPY nginx.conf /etc/nginx/nginx.conf
COPY start-chat-ui.sh /usr/local/bin/start-chat-ui

RUN chmod +x /usr/local/bin/start-chat-ui

EXPOSE 8080

CMD ["/usr/local/bin/start-chat-ui"]
