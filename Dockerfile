# ===== Builder stage =====
FROM node:20 AS builder
WORKDIR /app

# Install deps (with dev deps for build)
COPY package.json package-lock.json ./
RUN npm ci --legacy-peer-deps

# Copy source and build
COPY . .
# NX 在容器里可能因为缓存机器ID报错，先清一下更稳
RUN npx nx reset
RUN npx prisma generate
RUN npx nx build api

# ===== Runtime stage =====
# ===== Runtime stage =====
FROM node:20-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

RUN apt-get update -y \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --legacy-peer-deps

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src/prisma ./src/prisma

# Copy generated Prisma client from builder
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./node_modules/@prisma/client

EXPOSE 3000
CMD ["node", "dist/api/main.js"]