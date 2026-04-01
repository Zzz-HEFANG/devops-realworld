# ===== Builder stage =====
FROM node:20 AS builder
WORKDIR /app

# Install deps (with dev deps for build)
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and build
COPY . .
# NX 在容器里可能因为缓存机器ID报错，先清一下更稳
RUN npx nx reset
RUN npx prisma generate
RUN npx nx build api

# ===== Runtime stage =====
FROM node:20-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Prisma 在 slim 镜像里经常缺 openssl / ca-certs
RUN apt-get update -y \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Install ONLY production deps (clean + reproducible)
COPY package.json package-lock.json ./
RUN npm ci

# Copy compiled output
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src/prisma ./src/prisma

RUN npx prisma generate --schema=src/prisma/schema.prisma

EXPOSE 3000
CMD ["node", "dist/api/main.js"]