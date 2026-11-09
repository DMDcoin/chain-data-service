# syntax=docker/dockerfile:1

FROM node:26-alpine@sha256:8996bb5821d62a8fd9bb27c1cb07462f3fdce6e47d640c6a881ead0b064ce216 AS build

WORKDIR /app

# toolchain for bcrypt in case no prebuilt binary matches the platform
RUN apk add --no-cache python3 make g++

COPY package.json package-lock.json ./

# bcrypt is the only dependency whose install script is required
RUN npm ci --ignore-scripts --no-audit --no-fund \
    && npm rebuild bcrypt

COPY tsconfig.json ./
COPY src ./src

RUN npm run build \
    && npm prune --omit=dev --ignore-scripts --no-audit --no-fund

FROM node:26-alpine@sha256:8996bb5821d62a8fd9bb27c1cb07462f3fdce6e47d640c6a881ead0b064ce216

LABEL org.opencontainers.image.title="chain-data-service" \
      org.opencontainers.image.licenses="AGPL-3.0-only"

ENV NODE_ENV=production

WORKDIR /app

COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist

USER node

EXPOSE 4000

CMD ["node", "dist/app.js"]
